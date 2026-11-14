import UIKit

/// Keeps the user's own background photo in the app's Application Support folder.
enum PhotoStore {
    private static var url: URL? {
        guard let folder = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ) else { return nil }
        return folder.appendingPathComponent("background.jpg")
    }

    static var hasPhoto: Bool {
        guard let url else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    static func load() -> UIImage? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// Saves the picked image, scaled down so it is no larger than needed
    /// to fill a phone screen.
    @discardableResult
    static func save(_ data: Data, maxPixelHeight: CGFloat = 2900) -> Bool {
        guard let url, let image = UIImage(data: data) else { return false }
        let pixelHeight = image.size.height * image.scale
        let factor = min(1, maxPixelHeight / max(pixelHeight, 1))
        let target = CGSize(width: image.size.width * image.scale * factor, height: pixelHeight * factor)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let scaled = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        guard let jpeg = scaled.jpegData(compressionQuality: 0.88) else { return false }
        do {
            try jpeg.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    static func delete() {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
