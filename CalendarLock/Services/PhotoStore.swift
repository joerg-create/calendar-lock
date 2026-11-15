import UIKit

/// One of the user's background photos and how it is framed.
struct PhotoEntry: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    /// The point of the photo (0...1 in both directions) that is kept in the
    /// middle of the screen, as far as the photo allows.
    var focusX: Double = 0.5
    var focusY: Double = 0.5
    /// 1 fills the screen; larger values zoom in.
    var zoom: Double = 1

    static let zoomRange: ClosedRange<Double> = 1...4
}

/// Keeps the user's background photos in Application Support/Photos:
/// a full-size JPEG and a small thumbnail per photo, plus a JSON list with
/// the order and framing.
enum PhotoStore {
    private static let indexName = "photos.json"
    private static let fileManager = FileManager.default

    private static var folder: URL? {
        guard let support = try? fileManager.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ) else { return nil }
        let folder = support.appendingPathComponent("Photos", isDirectory: true)
        if !fileManager.fileExists(atPath: folder.path) {
            try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    private static func imageURL(_ id: UUID) -> URL? { folder?.appendingPathComponent("\(id.uuidString).jpg") }
    private static func thumbnailURL(_ id: UUID) -> URL? { folder?.appendingPathComponent("\(id.uuidString)-thumb.jpg") }

    // MARK: List

    static func entries() -> [PhotoEntry] {
        migrateSinglePhotoIfNeeded()
        guard let url = folder?.appendingPathComponent(indexName),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([PhotoEntry].self, from: data)
        else { return [] }
        return entries.filter { id in imageURL(id.id).map { fileManager.fileExists(atPath: $0.path) } ?? false }
    }

    static func saveEntries(_ entries: [PhotoEntry]) {
        guard let url = folder?.appendingPathComponent(indexName),
              let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func update(_ entry: PhotoEntry) {
        var all = entries()
        guard let index = all.firstIndex(where: { $0.id == entry.id }) else { return }
        all[index] = entry
        saveEntries(all)
    }

    // MARK: Images

    static func image(for entry: PhotoEntry) -> UIImage? {
        guard let url = imageURL(entry.id), let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    static func thumbnail(for entry: PhotoEntry) -> UIImage? {
        guard let url = thumbnailURL(entry.id), let data = try? Data(contentsOf: url) else { return image(for: entry) }
        return UIImage(data: data)
    }

    /// The photo for the given day. With several photos a different one is used
    /// every day, going through the list in order.
    static func photo(for date: Date, calendar: Calendar = .current) -> (entry: PhotoEntry, image: UIImage)? {
        let all = entries()
        guard let index = rotationIndex(count: all.count, date: date, calendar: calendar) else { return nil }
        let entry = all[index]
        guard let image = image(for: entry) else { return nil }
        return (entry, image)
    }

    /// Which photo of `count` belongs to `date`: counts whole days since a fixed
    /// start, so the order stays the same across months and years.
    static func rotationIndex(count: Int, date: Date, calendar: Calendar = .current) -> Int? {
        guard count > 0 else { return nil }
        let reference = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1)) ?? Date(timeIntervalSince1970: 0)
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: reference), to: calendar.startOfDay(for: date)).day ?? 0
        return ((days % count) + count) % count
    }

    // MARK: Changes

    /// Adds a picked image, scaled down so it is no larger than needed to fill a phone screen.
    @discardableResult
    static func add(_ data: Data, maxPixelHeight: CGFloat = 2900) -> PhotoEntry? {
        guard let image = UIImage(data: data) else { return nil }
        let entry = PhotoEntry()
        guard let url = imageURL(entry.id), let thumbURL = thumbnailURL(entry.id),
              let full = scaled(image, maxPixelHeight: maxPixelHeight).jpegData(compressionQuality: 0.88),
              let thumb = scaled(image, maxPixelHeight: 400).jpegData(compressionQuality: 0.8)
        else { return nil }
        do {
            try full.write(to: url, options: .atomic)
            try thumb.write(to: thumbURL, options: .atomic)
        } catch {
            return nil
        }
        saveEntries(entries() + [entry])
        return entry
    }

    static func delete(_ entry: PhotoEntry) {
        if let url = imageURL(entry.id) { try? fileManager.removeItem(at: url) }
        if let url = thumbnailURL(entry.id) { try? fileManager.removeItem(at: url) }
        saveEntries(entries().filter { $0.id != entry.id })
    }

    static func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        var all = entries()
        all.move(fromOffsets: source, toOffset: destination)
        saveEntries(all)
    }

    // MARK: Helpers

    private static func scaled(_ image: UIImage, maxPixelHeight: CGFloat) -> UIImage {
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let factor = min(1, maxPixelHeight / max(pixelSize.height, 1))
        let target = CGSize(width: (pixelSize.width * factor).rounded(), height: (pixelSize.height * factor).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    /// Version 0.1 kept a single photo at Application Support/background.jpg.
    private static func migrateSinglePhotoIfNeeded() {
        guard let support = try? fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        else { return }
        let old = support.appendingPathComponent("background.jpg")
        guard fileManager.fileExists(atPath: old.path), let data = try? Data(contentsOf: old) else { return }
        try? fileManager.removeItem(at: old)
        add(data)
    }
}
