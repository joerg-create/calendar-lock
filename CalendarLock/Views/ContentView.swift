import PhotosUI
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var settings = WallpaperSettings.load()
    @State private var hasAccess = CalendarService.shared.hasEventAccess
    @State private var calendars: [CalendarService.Source] = []
    @State private var reminderLists: [CalendarService.Source] = []
    @State private var preview: UIImage?
    @State private var errorText: String?
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var photos: [PhotoEntry] = PhotoStore.entries()
    @State private var editingPhoto: PhotoEntry?

    var body: some View {
        NavigationStack {
            Form {
                if hasAccess {
                    previewSection
                    artworkSection
                    appearanceSection
                    extrasSection
                    WeatherSection(settings: $settings)
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
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await addPhotos(items) }
        }
        .sheet(item: $editingPhoto) { entry in
            if let image = PhotoStore.image(for: entry) {
                PhotoEditorView(
                    entry: entry,
                    image: image,
                    dimming: settings.photoDimming,
                    onSave: { updated in
                        PhotoStore.update(updated)
                        photosChanged()
                    },
                    onDelete: { removed in
                        PhotoStore.delete(removed)
                        photosChanged()
                    }
                )
            }
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

    private var artworkSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Artwork.allCases) { artwork in
                        ArtworkThumbnail(
                            artwork: artwork,
                            theme: settings.theme,
                            photo: artwork == .photo ? photos.first.flatMap(PhotoStore.thumbnail(for:)) : nil,
                            isSelected: settings.artwork == artwork
                        )
                        .onTapGesture { settings.artwork = artwork }
                    }
                }
                .padding(.vertical, 4)
            }

            PhotosPicker(selection: $photoItems, maxSelectionCount: 30, matching: .images) {
                Label("Eigene Fotos hinzufügen", systemImage: "photo.badge.plus")
            }

            if settings.artwork == .photo && !photos.isEmpty {
                PhotoStrip(photos: photos, today: todaysPhotoID) { entry in
                    editingPhoto = entry
                }
                VStack(alignment: .leading) {
                    Text("Abdunkeln")
                    Slider(value: $settings.photoDimming, in: 0...1)
                }
            }
        } header: {
            Text("Hintergrund")
        } footer: {
            if settings.artwork == .photo {
                Text(photos.count > 1
                     ? "Jeden Tag kommt das nächste Foto dran. Tippe auf ein Foto, um den Ausschnitt zu verschieben oder es zu entfernen."
                     : "Tippe auf das Foto, um den Ausschnitt zu verschieben. Mit mehreren Fotos wechselt der Hintergrund jeden Tag.")
            } else {
                Text("Die Motive verändern sich jeden Tag ein wenig. Ihre Farben kommen vom Farbthema.")
            }
        }
    }

    private var todaysPhotoID: UUID? {
        PhotoStore.rotationIndex(count: photos.count, date: Date()).map { photos[$0].id }
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
            Stepper(value: $settings.daysAhead, in: 0...WallpaperSettings.maxDaysAhead) {
                LabeledContent("Nächste Tage", value: settings.daysAhead == 0 ? "aus" : "\(settings.daysAhead)")
            }
            Toggle("Vergangene Termine ausblenden", isOn: $settings.hidePastEvents)
        }
    }

    private var extrasSection: some View {
        Section("Kalenderwochen") {
            Toggle("Kalenderwoche anzeigen", isOn: $settings.showWeekNumber)
            Toggle("Monatsübersicht mit KW", isOn: $settings.showMonth)
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

    private func addPhotos(_ items: [PhotosPickerItem]) async {
        var failed = 0
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self), PhotoStore.add(data) != nil {
                continue
            }
            failed += 1
        }
        photoItems = []
        settings.artwork = .photo
        photosChanged()
        if failed > 0 {
            errorText = failed == 1 ? "Ein Foto konnte nicht geladen werden." : "\(failed) Fotos konnten nicht geladen werden."
        }
    }

    private func photosChanged() {
        photos = PhotoStore.entries()
        Task { await renderPreview() }
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

/// A small live preview of one background motif.
private struct ArtworkThumbnail: View {
    let artwork: Artwork
    let theme: WallpaperTheme
    let photo: UIImage?
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                WallpaperBackground(theme: theme, artwork: artwork, photo: photo, seed: 7)
                if artwork == .photo && photo == nil {
                    Image(systemName: "photo.badge.plus")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 66, height: 132)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isSelected ? 3 : 1)
            )
            Text(artwork.label)
                .font(.caption)
                .foregroundStyle(isSelected ? .primary : .secondary)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(artwork.label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// The user's photos in order. The one shown today is marked.
private struct PhotoStrip: View {
    let photos: [PhotoEntry]
    let today: UUID?
    let onSelect: (PhotoEntry) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(photos) { entry in
                    Button { onSelect(entry) } label: {
                        ZStack(alignment: .bottom) {
                            if let thumb = PhotoStore.thumbnail(for: entry) {
                                PhotoFill(image: thumb, framing: entry)
                            } else {
                                Color.secondary.opacity(0.2)
                            }
                            if entry.id == today {
                                Text("Heute")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(.ultraThinMaterial))
                                    .padding(4)
                            }
                        }
                        .frame(width: 54, height: 108)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(entry.id == today ? Color.accentColor : .clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(entry.id == today ? "Foto von heute, Ausschnitt bearbeiten" : "Foto, Ausschnitt bearbeiten")
                }
            }
            .padding(.vertical, 4)
        }
    }
}

/// Turns the forecast on and lets the user search for a place.
private struct WeatherSection: View {
    @Binding var settings: WallpaperSettings
    @State private var query = ""
    @State private var results: [WeatherLocation] = []
    @State private var isSearching = false
    @State private var message: String?

    var body: some View {
        Section {
            Toggle("Wetter für 5 Tage", isOn: $settings.showWeather)
            if settings.showWeather {
                if let location = settings.weatherLocation {
                    LabeledContent("Ort", value: location.name)
                }
                VStack(alignment: .leading) {
                    Text("Abstand zur Uhr")
                    Slider(value: $settings.weatherTop, in: WallpaperSettings.weatherTopRange)
                }
                HStack {
                    TextField("Ort suchen, z. B. Hamburg", text: $query)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit { Task { await search() } }
                    if isSearching {
                        ProgressView()
                    } else {
                        Button("Suchen") { Task { await search() } }
                            .disabled(query.trimmingCharacters(in: .whitespaces).count < 2)
                    }
                }
                ForEach(results, id: \.self) { place in
                    Button(place.name) {
                        settings.weatherLocation = place
                        results = []
                        query = ""
                    }
                }
                if let message {
                    Text(message).font(.footnote).foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Wetter")
        } footer: {
            Text("Das Wetter steht direkt unter der Uhr. Hast du Widgets auf dem Sperrbildschirm, schieb den Regler etwas nach rechts. Wetterdaten von Open-Meteo.com (CC BY 4.0).")
        }
    }

    private func search() async {
        isSearching = true
        defer { isSearching = false }
        do {
            results = try await WeatherService.searchPlaces(query)
            message = results.isEmpty ? "Kein Ort gefunden." : nil
        } catch {
            results = []
            message = "Die Suche hat nicht geklappt. Bist du online?"
        }
    }
}

#Preview {
    ContentView()
}
