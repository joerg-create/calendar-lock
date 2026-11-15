import EventKit
import Foundation

/// Reads events and reminders from the calendars already set up on the iPhone
/// (iCloud, Google, Outlook, ...). Everything stays on the device.
final class CalendarService {
    static let shared = CalendarService()

    private let store = EKEventStore()

    // MARK: Access

    var hasEventAccess: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    var hasReminderAccess: Bool {
        EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
    }

    /// Asks for calendar access, and for reminders when `includeReminders` is set.
    /// Returns whether calendar access was granted.
    @discardableResult
    func requestAccess(includeReminders: Bool) async -> Bool {
        let events = (try? await store.requestFullAccessToEvents()) ?? false
        if includeReminders {
            _ = try? await store.requestFullAccessToReminders()
        }
        // Calendars added after the store was created only show up after a reset.
        store.reset()
        return events
    }

    // MARK: Sources

    struct Source: Identifiable, Hashable {
        var id: String
        var title: String
        var account: String
        var color: RGBColor
    }

    func eventCalendars() -> [Source] {
        guard hasEventAccess else { return [] }
        return store.calendars(for: .event).map(Self.source).sorted(by: Self.bySourceThenTitle)
    }

    func reminderLists() -> [Source] {
        guard hasReminderAccess else { return [] }
        return store.calendars(for: .reminder).map(Self.source).sorted(by: Self.bySourceThenTitle)
    }

    // MARK: Agenda

    /// Builds the agenda for the day that contains `date`.
    func agenda(for date: Date, settings: WallpaperSettings, includeReminders: Bool, now: Date = Date()) async -> DayAgenda {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return .empty(for: date)
        }

        var events: [AgendaItem] = []
        if hasEventAccess {
            let calendars = filtered(store.calendars(for: .event), by: settings.calendarIDs)
            if !calendars.isEmpty {
                let predicate = store.predicateForEvents(withStart: dayStart, end: dayEnd, calendars: calendars)
                events = store.events(matching: predicate).map(Self.item)
            }
            if settings.hidePastEvents && calendar.isDate(date, inSameDayAs: now) {
                events = AgendaLayout.upcoming(events, now: now)
            }
        }

        var reminders: [AgendaItem] = []
        if includeReminders && settings.showReminders && hasReminderAccess {
            let lists = filtered(store.calendars(for: .reminder), by: settings.reminderListIDs)
            if !lists.isEmpty {
                // Incomplete reminders due up to the end of the day, overdue ones included.
                let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: dayEnd, calendars: lists)
                reminders = await fetchReminders(matching: predicate, dayStart: dayStart)
            }
        }

        return DayAgenda(
            date: dayStart,
            events: AgendaLayout.sortedEvents(events),
            reminders: AgendaLayout.sortedReminders(reminders)
        )
    }

    /// Start-of-day dates in the month of `date` that have at least one event,
    /// for the dots in the month overview.
    func daysWithEvents(inMonthOf date: Date, settings: WallpaperSettings) -> Set<Date> {
        guard hasEventAccess,
              let month = Calendar.current.dateInterval(of: .month, for: date)
        else { return [] }
        let calendars = filtered(store.calendars(for: .event), by: settings.calendarIDs)
        guard !calendars.isEmpty else { return [] }
        let predicate = store.predicateForEvents(withStart: month.start, end: month.end, calendars: calendars)
        var days = Set<Date>()
        let calendar = Calendar.current
        for event in store.events(matching: predicate) {
            // Multi-day events mark every day they touch inside the month.
            var day = calendar.startOfDay(for: max(event.startDate, month.start))
            let last = min(event.endDate, month.end)
            repeat {
                days.insert(day)
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            } while day < last
        }
        return days
    }

    // MARK: Helpers

    private func filtered(_ calendars: [EKCalendar], by ids: Set<String>) -> [EKCalendar] {
        ids.isEmpty ? calendars : calendars.filter { ids.contains($0.calendarIdentifier) }
    }

    private func fetchReminders(matching predicate: NSPredicate, dayStart: Date) async -> [AgendaItem] {
        await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                // Map inside the callback: EKReminder must not leave EventKit's queue.
                let items = (reminders ?? []).map { Self.item(from: $0, dayStart: dayStart) }
                continuation.resume(returning: items)
            }
        }
    }

    private static func item(_ event: EKEvent) -> AgendaItem {
        AgendaItem(
            id: event.calendarItemIdentifier + "-" + String(event.startDate.timeIntervalSince1970),
            kind: .event,
            title: displayTitle(event.title),
            start: event.startDate,
            end: event.endDate,
            isAllDay: event.isAllDay,
            isOverdue: false,
            color: color(of: event.calendar)
        )
    }

    private static func item(from reminder: EKReminder, dayStart: Date) -> AgendaItem {
        let due = reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) }
        let hasTime = reminder.dueDateComponents?.hour != nil
        return AgendaItem(
            id: reminder.calendarItemIdentifier,
            kind: .reminder,
            title: displayTitle(reminder.title),
            start: due,
            end: nil,
            isAllDay: !hasTime,
            isOverdue: due.map { $0 < dayStart } ?? false,
            color: color(of: reminder.calendar)
        )
    }

    private static func displayTitle(_ title: String?) -> String {
        let trimmed = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Ohne Titel" : trimmed
    }

    private static func source(_ calendar: EKCalendar) -> Source {
        Source(
            id: calendar.calendarIdentifier,
            title: calendar.title,
            account: calendar.source?.title ?? "",
            color: color(of: calendar)
        )
    }

    private static func bySourceThenTitle(_ lhs: Source, _ rhs: Source) -> Bool {
        if lhs.account != rhs.account { return lhs.account.localizedCompare(rhs.account) == .orderedAscending }
        return lhs.title.localizedCompare(rhs.title) == .orderedAscending
    }

    private static func color(of calendar: EKCalendar?) -> RGBColor {
        guard let cgColor = calendar?.cgColor,
              let srgb = CGColorSpace(name: CGColorSpace.sRGB),
              let converted = cgColor.converted(to: srgb, intent: .defaultIntent, options: nil),
              let c = converted.components, c.count >= 3
        else { return .gray }
        return RGBColor(red: Double(c[0]), green: Double(c[1]), blue: Double(c[2]))
    }
}
