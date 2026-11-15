import SwiftUI

extension RGBColor {
    var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: 1) }
}

/// Everything the wallpaper shows, collected before drawing.
struct WallpaperContent {
    var now: Date
    var today: DayAgenda
    /// The days after today, in order, for "Nächste Tage".
    var upcoming: [DayAgenda] = []
    var forecast: [DailyForecast] = []
    var month: MonthGrid?
    var eventDays: Set<Date> = []
    var photo: UIImage?
    var photoFraming = PhotoEntry()

    static func sample(now: Date = Date()) -> WallpaperContent {
        func event(_ id: String, _ title: String, hours: Double, allDay: Bool = false, _ color: RGBColor) -> AgendaItem {
            AgendaItem(id: id, kind: .event, title: title, start: now.addingTimeInterval(hours * 3600),
                       end: now.addingTimeInterval((hours + 1) * 3600), isAllDay: allDay, isOverdue: false, color: color)
        }
        let today = DayAgenda(
            date: now,
            events: [
                event("1", "Geburtstag Anna", hours: 0, allDay: true, RGBColor(red: 0.9, green: 0.3, blue: 0.4)),
                event("2", "Zahnarzt", hours: 1, RGBColor(red: 0.2, green: 0.6, blue: 0.95)),
                event("3", "Team-Call", hours: 3, RGBColor(red: 0.3, green: 0.8, blue: 0.5)),
            ],
            reminders: [
                AgendaItem(id: "4", kind: .reminder, title: "Paket abholen", start: nil, end: nil, isAllDay: true,
                           isOverdue: true, color: RGBColor(red: 1, green: 0.6, blue: 0.2)),
            ]
        )
        let forecast = (0..<5).map { offset in
            DailyForecast(date: Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: now))!,
                          code: [0, 2, 3, 61, 71][offset], high: Double(12 - offset), low: Double(4 - offset))
        }
        let upcoming = (1...3).map { offset -> DayAgenda in
            let day = Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: now))!
            let base = day.addingTimeInterval(9 * 3600)
            return DayAgenda(date: day, events: offset == 2 ? [] : [
                AgendaItem(id: "u\(offset)a", kind: .event, title: offset == 1 ? "Brunch bei Lena" : "Elternabend",
                           start: base, end: base.addingTimeInterval(3600), isAllDay: false, isOverdue: false,
                           color: RGBColor(red: 0.2, green: 0.6, blue: 0.95)),
                AgendaItem(id: "u\(offset)b", kind: .event, title: "Sport", start: base.addingTimeInterval(8 * 3600),
                           end: base.addingTimeInterval(9 * 3600), isAllDay: false, isOverdue: false,
                           color: RGBColor(red: 0.3, green: 0.8, blue: 0.5)),
            ], reminders: [])
        }
        return WallpaperContent(now: now, today: today, upcoming: upcoming, forecast: forecast, month: MonthGrid.make(for: now))
    }
}

/// The full-screen wallpaper image. Drawn at screen size in points.
///
/// The top ~37 % of the screen stays empty for the Lock Screen date, clock and
/// widgets, and the bottom ~13 % for the flashlight and camera buttons. Below the
/// clock come, top to bottom: weather, agenda and month overview.
struct WallpaperView: View {
    let content: WallpaperContent
    let settings: WallpaperSettings
    let size: CGSize

    private var theme: WallpaperTheme { settings.theme }
    private var fontSize: CGFloat {
        let range = WallpaperSettings.fontPointsRange
        return CGFloat(min(max(settings.fontPoints, range.lowerBound), range.upperBound))
    }
    private var margin: CGFloat { size.width * 0.06 }
    private var usesPhoto: Bool { settings.artwork == .photo && content.photo != nil }
    /// On a photo the text is always light, because the photo is darkened.
    private var textColor: Color { usesPhoto ? .white : theme.text.color }
    private var cardFill: Color {
        usesPhoto ? Color.black.opacity(0.28) : Color.white.opacity(theme.cardOpacity)
    }
    private var showsWeather: Bool { settings.showWeather && !content.forecast.isEmpty }
    private var weatherFontSize: CGFloat {
        let range = WallpaperSettings.weatherScaleRange
        return fontSize * CGFloat(min(max(settings.weatherScale, range.lowerBound), range.upperBound))
    }
    private var weatherTop: CGFloat {
        CGFloat(min(max(settings.weatherTop, WallpaperSettings.weatherTopRange.lowerBound), WallpaperSettings.weatherTopRange.upperBound))
    }
    /// Height of the weather card in points.
    private var weatherCardHeight: CGFloat { weatherFontSize * (WeatherStrip.heightFactor + 0.9) }
    /// Where the agenda starts: below the weather when it is shown, otherwise
    /// below the clock and the Lock Screen widgets.
    private var contentTop: CGFloat {
        guard showsWeather else { return Layout.contentTop }
        return weatherTop + (weatherCardHeight + fontSize * Layout.blockSpacing) / size.height
    }
    private var showsMonth: Bool { settings.showMonth && content.month != nil }

    private var daySeed: UInt64 {
        UInt64(Calendar.current.ordinality(of: .day, in: .year, for: content.now) ?? 1)
    }

    var body: some View {
        ZStack(alignment: .top) {
            WallpaperBackground(theme: theme, artwork: settings.artwork, photo: content.photo,
                                framing: content.photoFraming, dimming: settings.photoDimming, seed: daySeed)

            VStack(spacing: fontSize * Layout.blockSpacing) {

                VStack(alignment: .leading, spacing: fontSize * 0.9) {
                    section(for: content.today, title: "Heute", maxRows: rowBudget.today)
                    if hasUpcoming && rowBudget.upcoming > 0 {
                        Divider().overlay(textColor.opacity(0.25))
                        upcomingSection(maxRows: rowBudget.upcoming)
                    }
                }
                .padding(fontSize)
                .frame(width: size.width - 2 * margin, alignment: .leading)
                .background(card)

                if showsMonth, let month = content.month {
                    MonthOverview(grid: month, today: content.now, eventDays: content.eventDays,
                                  fontSize: fontSize * 0.78, textColor: textColor,
                                  highlightText: (!usesPhoto && theme.isLight) ? .white : .black.opacity(0.85))
                        .padding(fontSize * 0.8)
                        .frame(width: size.width - 2 * margin)
                        .background(card)
                }
            }
            .padding(.top, size.height * contentTop)

            if showsWeather {
                WeatherStrip(days: content.forecast, fontSize: weatherFontSize, textColor: textColor)
                    .padding(.vertical, weatherFontSize * 0.45)
                    .padding(.horizontal, weatherFontSize * 0.5)
                    .frame(width: size.width - 2 * margin)
                    .background(card)
                    .padding(.top, size.height * weatherTop)
            }
        }
        .frame(width: size.width, height: size.height)
        .foregroundStyle(textColor)
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: fontSize * 1.1, style: .continuous).fill(cardFill)
    }

    // MARK: Sections

    @ViewBuilder
    private func section(for agenda: DayAgenda, title: String, maxRows: Int) -> some View {
        VStack(alignment: .leading, spacing: fontSize * 0.45) {
            HStack(alignment: .firstTextBaseline, spacing: fontSize * 0.4) {
                Text(title)
                    .font(.system(size: fontSize * 1.05, weight: .bold, design: .rounded))
                Text(agenda.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.system(size: fontSize * 0.85, weight: .medium, design: .rounded))
                    .opacity(0.7)
                    // Keep the header on one line, the row budget counts it as one.
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if settings.showWeekNumber && showsWeekNumber(for: agenda) {
                    Spacer(minLength: 0)
                    Text("KW \(MonthGrid.weekNumber(of: agenda.date))")
                        .font(.system(size: fontSize * 0.78, weight: .semibold, design: .rounded).monospacedDigit())
                        .padding(.horizontal, fontSize * 0.4)
                        .padding(.vertical, fontSize * 0.12)
                        .background(Capsule().fill(textColor.opacity(0.14)))
                }
            }

            if agenda.isEmpty {
                Text("Nichts im Kalender")
                    .font(.system(size: fontSize, weight: .regular, design: .rounded))
                    .opacity(0.7)
            } else {
                let fitted = AgendaLayout.fit(agenda.events + agenda.reminders, maxRows: maxRows)
                ForEach(fitted.visible) { item in
                    row(for: item)
                }
                if fitted.hidden > 0 {
                    Text("+ \(fitted.hidden) weitere")
                        .font(.system(size: fontSize * 0.85, weight: .medium, design: .rounded))
                        .opacity(0.65)
                }
            }
        }
    }

    private var hasUpcoming: Bool { content.upcoming.contains { !$0.events.isEmpty } }

    @ViewBuilder
    private func upcomingSection(maxRows: Int) -> some View {
        let fitted = AgendaLayout.upcomingRows(content.upcoming, maxRows: maxRows)
        VStack(alignment: .leading, spacing: fontSize * 0.45) {
            Text("Nächste Tage")
                .font(.system(size: fontSize * 1.05, weight: .bold, design: .rounded))
            ForEach(fitted.rows) { line in
                HStack(alignment: .center, spacing: fontSize * 0.55) {
                    Text(line.startsDay ? dayLabel(line.day) : "")
                        .font(.system(size: fontSize * 0.85, weight: .bold, design: .rounded).monospacedDigit())
                        .frame(width: fontSize * 3.3, alignment: .leading)
                    Capsule()
                        .fill(line.item.color.color)
                        .frame(width: fontSize * 0.22, height: fontSize * 1.15)
                    Text(line.item.isAllDay ? "ganzt." : timeLabel(for: line.item))
                        .font(.system(size: fontSize * 0.85, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(textColor.opacity(0.75))
                        .frame(width: fontSize * 3.0, alignment: .leading)
                    Text(line.item.title)
                        .font(.system(size: fontSize, weight: .medium, design: .rounded))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(height: fontSize * Layout.rowHeightFactor)
            }
            if fitted.hidden > 0 {
                Text("+ \(fitted.hidden) weitere")
                    .font(.system(size: fontSize * 0.85, weight: .medium, design: .rounded))
                    .opacity(0.65)
            }
        }
    }

    /// "Mo 16." for a day in the coming-days list.
    private func dayLabel(_ date: Date) -> String {
        let weekday = date.formatted(.dateTime.weekday(.abbreviated)).replacingOccurrences(of: ".", with: "")
        let day = Calendar.current.component(.day, from: date)
        return "\(weekday) \(day)."
    }

    @ViewBuilder
    private func row(for item: AgendaItem) -> some View {
        HStack(alignment: .center, spacing: fontSize * 0.55) {
            switch item.kind {
            case .event:
                Capsule()
                    .fill(item.color.color)
                    .frame(width: fontSize * 0.22, height: fontSize * 1.15)
            case .reminder:
                Circle()
                    .strokeBorder(item.color.color, lineWidth: fontSize * 0.11)
                    .frame(width: fontSize * 0.85, height: fontSize * 0.85)
            }

            Text(timeLabel(for: item))
                .font(.system(size: fontSize * 0.85, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(item.isOverdue ? Color(red: 1, green: 0.42, blue: 0.38) : textColor.opacity(0.75))
                .frame(width: max(fontSize * 4.2, 50), alignment: .leading)

            Text(item.title)
                .font(.system(size: fontSize, weight: .medium, design: .rounded))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(height: fontSize * Layout.rowHeightFactor)
    }

    /// Tomorrow only repeats the week number when a new week starts.
    private func showsWeekNumber(for agenda: DayAgenda) -> Bool {
        guard !Calendar.current.isDate(agenda.date, inSameDayAs: content.today.date) else { return true }
        return MonthGrid.weekNumber(of: agenda.date) != MonthGrid.weekNumber(of: content.today.date)
    }

    private func timeLabel(for item: AgendaItem) -> String {
        if item.isOverdue { return "überfällig" }
        if item.isAllDay { return item.kind == .event ? "ganztägig" : "heute" }
        guard let start = item.start else { return "" }
        return start.formatted(date: .omitted, time: .shortened)
    }

    // MARK: Row budget

    private enum Layout {
        /// Where the content starts, as a fraction of the screen height.
        static let contentTop: CGFloat = 0.37
        /// Lowest point the content may reach, as a fraction of the screen height.
        static let contentBottom: CGFloat = 0.87
        static let rowHeightFactor: CGFloat = 1.6
        static let blockSpacing: CGFloat = 0.7
    }

    /// Height in points of the month card, including the spacing above it.
    private var monthHeight: CGFloat {
        guard showsMonth, let month = content.month else { return 0 }
        let small = fontSize * 0.78
        return MonthOverview.height(weeks: month.weeks.count, fontSize: small) + fontSize * (1.6 + Layout.blockSpacing)
    }

    /// How many agenda rows fit for today and the coming days.
    private var rowBudget: (today: Int, upcoming: Int) {
        let rowStep = fontSize * (Layout.rowHeightFactor + 0.45)
        let headerHeight = fontSize * 1.9
        // `fit` reserves a full row for "+ N weitere", but that line is shorter.
        let moreLineSaving = rowStep - fontSize * 1.5
        var available = size.height * (Layout.contentBottom - contentTop) - fontSize * 2
        available -= monthHeight + headerHeight
        func rows(in space: CGFloat, sections: Int) -> Int {
            max(Int((space + moreLineSaving * CGFloat(sections)) / rowStep), 1)
        }
        let todayCount = content.today.events.count + content.today.reminders.count
        guard hasUpcoming else { return (rows(in: available, sections: 1), 0) }

        let upcomingCount = content.upcoming.reduce(0) { $0 + $1.events.count }
        let total = rows(in: available - headerHeight - fontSize * 1.8, sections: 2)
        let split = AgendaLayout.splitRows(total: total, todayCount: todayCount, upcomingCount: upcomingCount)
        // Too little room for the coming days: leave them out and give today the space.
        if split.upcoming == 0 { return (rows(in: available, sections: 1), 0) }
        return split
    }
}

/// Five days of weather in a row: weekday, symbol, high and low.
struct WeatherStrip: View {
    let days: [DailyForecast]
    let fontSize: CGFloat
    let textColor: Color

    /// Height of the strip in multiples of `fontSize`, used for the layout budget.
    static let heightFactor: CGFloat = 3.6

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                VStack(spacing: fontSize * 0.2) {
                    Text(index == 0 ? "Heute" : day.date.formatted(.dateTime.weekday(.abbreviated)))
                        .font(.system(size: fontSize * 0.72, weight: .semibold, design: .rounded))
                        .opacity(0.8)
                    Image(systemName: day.symbolName)
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: fontSize * 1.15))
                        .frame(height: fontSize * 1.35)
                    HStack(alignment: .firstTextBaseline, spacing: fontSize * 0.2) {
                        Text("\(Int(day.high.rounded()))°")
                            .font(.system(size: fontSize * 0.85, weight: .semibold, design: .rounded).monospacedDigit())
                        Text("\(Int(day.low.rounded()))°")
                            .font(.system(size: fontSize * 0.72, weight: .regular, design: .rounded).monospacedDigit())
                            .foregroundStyle(textColor.opacity(0.6))
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: fontSize * Self.heightFactor)
    }
}

/// The current month with ISO calendar weeks in the first column.
struct MonthOverview: View {
    let grid: MonthGrid
    let today: Date
    let eventDays: Set<Date>
    let fontSize: CGFloat
    let textColor: Color
    /// Color of today's number on the highlighted circle.
    let highlightText: Color

    static func height(weeks: Int, fontSize: CGFloat) -> CGFloat {
        // Title, weekday header and one row per week.
        fontSize * 1.6 + fontSize * 1.5 * CGFloat(weeks + 1)
    }

    private let weekdays = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

    var body: some View {
        let calendar = Calendar.current
        VStack(spacing: 0) {
            Text(grid.month.formatted(.dateTime.month(.wide).year()))
                .font(.system(size: fontSize * 1.05, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: fontSize * 1.6, alignment: .top)

            HStack(spacing: 0) {
                cell("KW", weight: .semibold, opacity: 0.5)
                ForEach(weekdays, id: \.self) { day in
                    cell(day, weight: .semibold, opacity: 0.6)
                }
            }

            ForEach(grid.weeks, id: \.number) { week in
                let isCurrentWeek = week.days.contains { $0.map { calendar.isDate($0, inSameDayAs: today) } ?? false }
                HStack(spacing: 0) {
                    cell("\(week.number)", weight: .bold, opacity: isCurrentWeek ? 1 : 0.5)
                    ForEach(0..<7, id: \.self) { index in
                        dayCell(week.days[index], calendar: calendar)
                    }
                }
                .background(
                    Capsule()
                        .fill(textColor.opacity(isCurrentWeek ? 0.1 : 0))
                )
            }
        }
    }

    private func cell(_ text: String, weight: Font.Weight, opacity: Double) -> some View {
        Text(text)
            .font(.system(size: fontSize * 0.9, weight: weight, design: .rounded).monospacedDigit())
            .opacity(opacity)
            .frame(maxWidth: .infinity)
            .frame(height: fontSize * 1.5)
    }

    @ViewBuilder
    private func dayCell(_ date: Date?, calendar: Calendar) -> some View {
        if let date {
            let isToday = calendar.isDate(date, inSameDayAs: today)
            let hasEvents = eventDays.contains(calendar.startOfDay(for: date))
            let isWeekend = calendar.isDateInWeekend(date)
            ZStack {
                if isToday {
                    Circle().fill(textColor).frame(width: fontSize * 1.4, height: fontSize * 1.4)
                }
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: fontSize, weight: isToday ? .bold : .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(isToday ? highlightText : textColor.opacity(isWeekend ? 0.6 : 0.95))
                if hasEvents && !isToday {
                    Circle().fill(textColor.opacity(0.8))
                        .frame(width: fontSize * 0.22, height: fontSize * 0.22)
                        .offset(y: fontSize * 0.62)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: fontSize * 1.5)
        } else {
            Color.clear.frame(maxWidth: .infinity).frame(height: fontSize * 1.5)
        }
    }
}

#Preview {
    var settings = WallpaperSettings()
    settings.showWeather = true
    settings.showMonth = true
    return WallpaperView(content: .sample(), settings: settings, size: CGSize(width: 393, height: 852))
}
