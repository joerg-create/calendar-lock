import Foundation

/// A color stored as plain sRGB components, so it can be kept in models and settings.
struct RGBColor: Hashable, Codable {
    var red: Double
    var green: Double
    var blue: Double

    static let gray = RGBColor(red: 0.6, green: 0.6, blue: 0.6)
}

/// One line on the wallpaper: a calendar event or a reminder.
struct AgendaItem: Identifiable, Hashable {
    enum Kind: Hashable {
        case event
        case reminder
    }

    var id: String
    var kind: Kind
    var title: String
    var start: Date?
    var end: Date?
    var isAllDay: Bool
    var isOverdue: Bool
    var color: RGBColor
}

/// Everything that is drawn for one day.
struct DayAgenda: Hashable {
    var date: Date
    var events: [AgendaItem]
    var reminders: [AgendaItem]

    var isEmpty: Bool { events.isEmpty && reminders.isEmpty }

    static func empty(for date: Date) -> DayAgenda {
        DayAgenda(date: date, events: [], reminders: [])
    }
}

/// Pure layout logic, kept free of UIKit and EventKit so it can be unit tested.
enum AgendaLayout {
    /// Sorts events the way they appear on the wallpaper: all-day events first,
    /// then by start time, then by title.
    static func sortedEvents(_ events: [AgendaItem]) -> [AgendaItem] {
        events.sorted { lhs, rhs in
            if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
            let lStart = lhs.start ?? .distantPast
            let rStart = rhs.start ?? .distantPast
            if lStart != rStart { return lStart < rStart }
            return lhs.title.localizedCompare(rhs.title) == .orderedAscending
        }
    }

    /// Sorts reminders: overdue first, then by due date, undated last.
    static func sortedReminders(_ reminders: [AgendaItem]) -> [AgendaItem] {
        reminders.sorted { lhs, rhs in
            if lhs.isOverdue != rhs.isOverdue { return lhs.isOverdue }
            switch (lhs.start, rhs.start) {
            case let (l?, r?) where l != r: return l < r
            case (nil, _?): return false
            case (_?, nil): return true
            default: return lhs.title.localizedCompare(rhs.title) == .orderedAscending
            }
        }
    }

    /// Drops events that already ended before `now`, so a wallpaper refreshed
    /// during the day only shows what is still ahead. All-day events stay.
    static func upcoming(_ events: [AgendaItem], now: Date) -> [AgendaItem] {
        events.filter { $0.isAllDay || ($0.end ?? $0.start ?? now) > now }
    }

    /// Splits items into the ones that fit in `maxRows` and the number left over.
    /// When items are cut, one row is reserved for the "+ N weitere" line.
    static func fit(_ items: [AgendaItem], maxRows: Int) -> (visible: [AgendaItem], hidden: Int) {
        guard maxRows > 0 else { return ([], items.count) }
        if items.count <= maxRows { return (items, 0) }
        let visibleCount = max(maxRows - 1, 0)
        return (Array(items.prefix(visibleCount)), items.count - visibleCount)
    }
}
