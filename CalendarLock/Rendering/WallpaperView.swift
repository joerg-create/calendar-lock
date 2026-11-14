import SwiftUI

extension RGBColor {
    var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: 1) }
}

/// The full-screen wallpaper image. Drawn at screen size in points.
///
/// The top ~37 % of the screen stays empty for the Lock Screen date, clock and
/// widgets, and the bottom ~13 % for the flashlight and camera buttons.
struct WallpaperView: View {
    let today: DayAgenda
    let tomorrow: DayAgenda?
    let settings: WallpaperSettings
    let size: CGSize

    private var theme: WallpaperTheme { settings.theme }
    private var fontSize: CGFloat { CGFloat(settings.textSize.points) }
    private var margin: CGFloat { size.width * 0.06 }

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [theme.background.top.color, theme.background.bottom.color],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: fontSize * 0.9) {
                section(for: today, title: "Heute", maxRows: rowBudget.today)
                if let tomorrow {
                    Divider().overlay(theme.text.color.opacity(0.25))
                    section(for: tomorrow, title: "Morgen", maxRows: rowBudget.tomorrow)
                }
            }
            .padding(fontSize)
            .frame(width: size.width - 2 * margin, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: fontSize * 1.1, style: .continuous)
                    .fill(Color.white.opacity(theme.cardOpacity))
            )
            .padding(.top, size.height * Layout.contentTop)
        }
        .frame(width: size.width, height: size.height)
        .foregroundStyle(theme.text.color)
    }

    // MARK: Sections

    @ViewBuilder
    private func section(for agenda: DayAgenda, title: String, maxRows: Int) -> some View {
        VStack(alignment: .leading, spacing: fontSize * 0.45) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: fontSize * 1.05, weight: .bold, design: .rounded))
                Text(agenda.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.system(size: fontSize * 0.85, weight: .medium, design: .rounded))
                    .opacity(0.7)
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
                .foregroundStyle(item.isOverdue ? Color(red: 1, green: 0.42, blue: 0.38) : theme.text.color.opacity(0.75))
                .frame(width: fontSize * 4.2, alignment: .leading)

            Text(item.title)
                .font(.system(size: fontSize, weight: .medium, design: .rounded))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(height: fontSize * Layout.rowHeightFactor)
    }

    private func timeLabel(for item: AgendaItem) -> String {
        if item.isOverdue { return "überfällig" }
        if item.isAllDay { return item.kind == .event ? "ganztägig" : "heute" }
        guard let start = item.start else { return "" }
        return start.formatted(date: .omitted, time: .shortened)
    }

    // MARK: Row budget

    private enum Layout {
        /// Where the card starts, as a fraction of the screen height.
        static let contentTop: CGFloat = 0.37
        /// Lowest point the card may reach, as a fraction of the screen height.
        static let contentBottom: CGFloat = 0.87
        static let rowHeightFactor: CGFloat = 1.6
    }

    /// How many rows fit for today and tomorrow.
    private var rowBudget: (today: Int, tomorrow: Int) {
        let rowStep = fontSize * (Layout.rowHeightFactor + 0.45)
        let headerHeight = fontSize * 1.9
        var available = size.height * (Layout.contentBottom - Layout.contentTop) - fontSize * 2
        available -= headerHeight
        if tomorrow != nil { available -= headerHeight + fontSize * 1.8 }
        let rows = max(Int(available / rowStep), 1)
        guard tomorrow != nil else { return (rows, 0) }
        let todayRows = max(Int((Double(rows) * 0.62).rounded()), 1)
        return (todayRows, max(rows - todayRows, 1))
    }
}

#Preview {
    let now = Date()
    let sample = DayAgenda(
        date: now,
        events: [
            AgendaItem(id: "1", kind: .event, title: "Geburtstag Anna", start: now, end: now, isAllDay: true, isOverdue: false, color: RGBColor(red: 0.9, green: 0.3, blue: 0.4)),
            AgendaItem(id: "2", kind: .event, title: "Zahnarzt", start: now.addingTimeInterval(3600), end: now.addingTimeInterval(5400), isAllDay: false, isOverdue: false, color: RGBColor(red: 0.2, green: 0.6, blue: 0.95)),
            AgendaItem(id: "3", kind: .event, title: "Team-Call", start: now.addingTimeInterval(7200), end: now.addingTimeInterval(9000), isAllDay: false, isOverdue: false, color: RGBColor(red: 0.3, green: 0.8, blue: 0.5)),
        ],
        reminders: [
            AgendaItem(id: "4", kind: .reminder, title: "Paket abholen", start: nil, end: nil, isAllDay: true, isOverdue: true, color: RGBColor(red: 1, green: 0.6, blue: 0.2)),
        ]
    )
    return WallpaperView(today: sample, tomorrow: nil, settings: WallpaperSettings(), size: CGSize(width: 393, height: 852))
}
