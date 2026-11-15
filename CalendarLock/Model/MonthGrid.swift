import Foundation

/// A month laid out in ISO weeks (Monday first), with the ISO week number of each row.
struct MonthGrid: Hashable {
    struct Week: Hashable {
        /// ISO 8601 calendar week ("KW").
        var number: Int
        /// Seven entries, Monday to Sunday. `nil` for days outside the month.
        var days: [Date?]
    }

    var month: Date
    var weeks: [Week]

    /// The calendar used for weeks: ISO 8601 (weeks start Monday, week 1 contains
    /// the first Thursday), as used in Germany. Time zone and locale follow the device.
    static var isoCalendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        calendar.locale = .current
        return calendar
    }

    static func weekNumber(of date: Date, calendar: Calendar = isoCalendar) -> Int {
        calendar.component(.weekOfYear, from: date)
    }

    static func make(for date: Date, calendar: Calendar = isoCalendar) -> MonthGrid {
        guard let interval = calendar.dateInterval(of: .month, for: date) else {
            return MonthGrid(month: date, weeks: [])
        }
        let monthStart = interval.start
        let dayCount = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30

        // Weekday of the first: 1 = Sunday ... 7 = Saturday. Shift to Monday = 0.
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leading = (firstWeekday + 5) % 7

        var cells: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<dayCount {
            cells.append(calendar.date(byAdding: .day, value: offset, to: monthStart))
        }
        while cells.count % 7 != 0 { cells.append(nil) }

        var weeks: [Week] = []
        for start in stride(from: 0, to: cells.count, by: 7) {
            let days = Array(cells[start..<start + 7])
            let anyDay = days.compactMap { $0 }.first ?? monthStart
            weeks.append(Week(number: weekNumber(of: anyDay, calendar: calendar), days: days))
        }
        return MonthGrid(month: monthStart, weeks: weeks)
    }
}
