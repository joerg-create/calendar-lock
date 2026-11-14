import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var settings = WallpaperSettings.load()
    @State private var hasAccess = CalendarService.shared.hasEventAccess
    @State private var calendars: [CalendarService.Source] = []
    @State private var reminderLists: [CalendarService.Source] = []
    @State private var preview: UIImage?
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                if hasAccess {
                    previewSection
                    appearanceSection
                    sourcesSection
                    SetupGuideSection()
                } else {
                    AccessSection {
                        Task { await requestAccess() }
                    }
                }
            }
            .navigationTitle("Calendar Lock")
        }
        .task { await reloadSources() }
        .task(id: settings) {
            settings.save()
            await renderPreview()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await reloadSources()
                await renderPreview()
            }
        }
    }

    // MARK: Sections

    private var previewSection: some View {
        Section {
            VStack(spacing: 12) {
                if let preview {
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 360)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(alignment: .top) { lockScreenHint }
                        .accessibilityLabel("Vorschau des Hintergrundbilds")
                } else if let errorText {
                    Text(errorText).foregroundStyle(.secondary)
                } else {
                    ProgressView().frame(height: 200)
                }

                if let preview {
                    ShareLink(
                        item: Image(uiImage: preview),
                        preview: SharePreview("Calendar Lock", image: Image(uiImage: preview))
                    ) {
                        Label("Bild teilen oder sichern", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        } footer: {
            Text("Die Uhrzeit zeigt iOS selbst. Der obere Bereich bleibt deshalb frei.")
        }
    }

    /// A rough stand-in for the Lock Screen clock, only in the in-app preview.
    private var lockScreenHint: some View {
        GeometryReader { proxy in
            Text("9:41")
                .font(.system(size: proxy.size.height * 0.1, weight: .semibold, design: .rounded))
                .foregroundStyle(settings.theme.text.color.opacity(0.35))
                .frame(maxWidth: .infinity)
                .padding(.top, proxy.size.height * 0.12)
        }
        .allowsHitTesting(false)
    }

    private var appearanceSection: some View {
        Section("Aussehen") {
            Picker("Farbthema", selection: $settings.theme) {
                ForEach(WallpaperTheme.allCases) { theme in
                    Text(theme.label).tag(theme)
                }
            }
            Picker("Schriftgröße", selection: $settings.textSize) {
                ForEach(WallpaperSettings.TextSize.allCases) { size in
                    Text(size.label).tag(size)
                }
            }
            Toggle("Erinnerungen anzeigen", isOn: $settings.showReminders)
            Toggle("Morgen auch anzeigen", isOn: $settings.showTomorrow)
            Toggle("Vergangene Termine ausblenden", isOn: $settings.hidePastEvents)
        }
    }

    private var sourcesSection: some View {
        Group {
            if !calendars.isEmpty {
                Section("Kalender") {
                    ForEach(calendars) { source in
                        SourceToggle(source: source, selection: $settings.calendarIDs, all: calendars)
                    }
                }
            }
            if settings.showReminders {
                Section("Erinnerungslisten") {
                    if reminderLists.isEmpty {
                        Button("Zugriff auf Erinnerungen erlauben") {
                            Task { await requestAccess() }
                        }
                    } else {
                        ForEach(reminderLists) { source in
                            SourceToggle(source: source, selection: $settings.reminderListIDs, all: reminderLists)
                        }
                    }
                }
            }
        }
    }

    // MARK: Actions

    private func requestAccess() async {
        hasAccess = await CalendarService.shared.requestAccess(includeReminders: settings.showReminders)
        await reloadSources()
        await renderPreview()
    }

    private func reloadSources() async {
        let service = CalendarService.shared
        hasAccess = service.hasEventAccess
        calendars = service.eventCalendars()
        reminderLists = service.reminderLists()
    }

    private func renderPreview() async {
        guard hasAccess else { return }
        do {
            preview = try await WallpaperBuilder.makeImage(settings: settings)
            errorText = nil
        } catch {
            preview = nil
            errorText = error.localizedDescription
        }
    }
}

/// A row that turns one calendar or reminder list on or off.
/// An empty selection means "all", so the first switch-off fills in the rest.
private struct SourceToggle: View {
    let source: CalendarService.Source
    @Binding var selection: Set<String>
    let all: [CalendarService.Source]

    var body: some View {
        Toggle(isOn: binding) {
            HStack(spacing: 10) {
                Circle().fill(source.color.color).frame(width: 12, height: 12)
                VStack(alignment: .leading) {
                    Text(source.title)
                    if !source.account.isEmpty {
                        Text(source.account).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var binding: Binding<Bool> {
        Binding(
            get: { selection.isEmpty || selection.contains(source.id) },
            set: { isOn in
                var ids = selection.isEmpty ? Set(all.map(\.id)) : selection
                if isOn { ids.insert(source.id) } else { ids.remove(source.id) }
                // Everything on again: store as "all" so new calendars show up too.
                selection = ids == Set(all.map(\.id)) ? [] : ids
            }
        )
    }
}

private struct AccessSection: View {
    let onRequest: () -> Void

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 44))
                    .foregroundStyle(.tint)
                Text("Deine Termine auf dem Sperrbildschirm")
                    .font(.title2.bold())
                Text("Calendar Lock zeichnet deine heutigen Termine und Erinnerungen in ein Hintergrundbild. Dafür braucht die App Zugriff auf deinen Kalender. Die Daten bleiben auf deinem iPhone.")
                    .foregroundStyle(.secondary)
                Button(action: onRequest) {
                    Text("Zugriff erlauben").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
                Text("Falls du den Zugriff schon abgelehnt hast: Einstellungen › Apps › Calendar Lock › Kalender.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        }
    }
}

private struct SetupGuideSection: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Section {
            step(1, "Öffne die Kurzbefehle-App und tippe auf „Automation“ › „+“ › „Tageszeit“.")
            step(2, "Wähle eine Uhrzeit, z. B. 6:00 Uhr, täglich, und „Sofort ausführen“.")
            step(3, "Füge die Aktion „Kalender-Hintergrund erstellen“ von Calendar Lock hinzu.")
            step(4, "Füge danach „Hintergrundbild festlegen“ hinzu, wähle deinen Sperrbildschirm und schalte „Vorschau zeigen“ aus.")
            Button("Kurzbefehle öffnen") {
                if let url = URL(string: "shortcuts://") { openURL(url) }
            }
        } header: {
            Text("Automatisch jeden Morgen")
        } footer: {
            Text("iOS erlaubt Apps nicht, das Hintergrundbild selbst zu wechseln. Die Automation erledigt das einmal am Tag. Du kannst sie auch mehrmals am Tag laufen lassen.")
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(.subheadline.bold())
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.accentColor.opacity(0.15)))
            Text(text)
        }
    }
}

#Preview {
    ContentView()
}
