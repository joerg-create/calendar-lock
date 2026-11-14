import SwiftUI

/// Lets the user move and zoom a photo inside the phone screen frame.
struct PhotoEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State var entry: PhotoEntry
    let image: UIImage
    let dimming: Double
    let onSave: (PhotoEntry) -> Void
    let onDelete: (PhotoEntry) -> Void

    @State private var dragStart: PhotoEntry?
    @State private var zoomStart: Double?
    @State private var confirmDelete = false

    /// Phone screen proportions (width / height) for the frame.
    private let screenAspect: CGFloat = {
        let bounds = UIScreen.main.nativeBounds
        return bounds.height > 0 ? bounds.width / bounds.height : 9.0 / 19.5
    }()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                GeometryReader { proxy in
                    let frameSize = fittedSize(in: proxy.size)
                    canvas(size: frameSize)
                        .frame(width: frameSize.width, height: frameSize.height)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                VStack(spacing: 6) {
                    HStack {
                        Image(systemName: "minus.magnifyingglass")
                        Slider(value: $entry.zoom, in: PhotoEntry.zoomRange)
                        Image(systemName: "plus.magnifyingglass")
                    }
                    Text("Ziehen zum Verschieben, mit zwei Fingern zoomen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                HStack {
                    Button("Zurücksetzen") {
                        entry.focusX = 0.5
                        entry.focusY = 0.5
                        entry.zoom = 1
                    }
                    Spacer()
                    Button("Foto entfernen", role: .destructive) { confirmDelete = true }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            .navigationTitle("Ausschnitt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        onSave(entry)
                        dismiss()
                    }
                }
            }
            .confirmationDialog("Foto aus Calendar Lock entfernen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Entfernen", role: .destructive) {
                    onDelete(entry)
                    dismiss()
                }
            } message: {
                Text("Das Original in deiner Fotos-App bleibt erhalten.")
            }
        }
    }

    private func fittedSize(in available: CGSize) -> CGSize {
        let height = min(available.height, available.width / screenAspect)
        return CGSize(width: height * screenAspect, height: height)
    }

    private func canvas(size: CGSize) -> some View {
        ZStack(alignment: .top) {
            WallpaperBackground(theme: .night, artwork: .photo, photo: image, framing: entry, dimming: dimming)
            // Where the Lock Screen clock and the agenda will be.
            Text("9:41")
                .font(.system(size: size.height * 0.1, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .padding(.top, size.height * 0.12)
            RoundedRectangle(cornerRadius: size.width * 0.05, style: .continuous)
                .strokeBorder(.white.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .frame(width: size.width * 0.88, height: size.height * 0.46)
                .padding(.top, size.height * 0.37)
        }
        .clipShape(RoundedRectangle(cornerRadius: size.width * 0.1, style: .continuous))
        .contentShape(Rectangle())
        .gesture(dragGesture(size: size).simultaneously(with: zoomGesture))
        .accessibilityLabel("Fotoausschnitt")
    }

    private func dragGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let start = dragStart ?? entry
                if dragStart == nil { dragStart = entry }
                let drawn = PhotoFill.frame(imageSize: image.size, in: size, framing: start).size
                entry.focusX = clamp(start.focusX - Double(value.translation.width / max(drawn.width, 1)))
                entry.focusY = clamp(start.focusY - Double(value.translation.height / max(drawn.height, 1)))
            }
            .onEnded { _ in
                dragStart = nil
                // Snap the focus to what is actually shown, so dragging back
                // from an edge responds right away.
                let rect = PhotoFill.frame(imageSize: image.size, in: size, framing: entry)
                entry.focusX = clamp(Double((size.width / 2 - rect.minX) / max(rect.width, 1)))
                entry.focusY = clamp(Double((size.height / 2 - rect.minY) / max(rect.height, 1)))
            }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let start = zoomStart ?? entry.zoom
                if zoomStart == nil { zoomStart = entry.zoom }
                let range = PhotoEntry.zoomRange
                entry.zoom = min(max(start * Double(value.magnification), range.lowerBound), range.upperBound)
            }
            .onEnded { _ in zoomStart = nil }
    }

    private func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }
}
