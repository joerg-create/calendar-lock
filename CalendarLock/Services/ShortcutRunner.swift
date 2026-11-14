import Foundation

/// Starts the user's shortcut in the Shortcuts app and comes back afterwards.
///
/// iOS cannot start an automation from an app, only a shortcut from the
/// library, by its name. Shortcuts opens briefly, runs it and then returns to
/// Calendar Lock through the `calendarlock://` URL.
enum ShortcutRunner {
    static let callbackScheme = "calendarlock"

    enum Result: String {
        case done, cancel, error
    }

    static func runURL(shortcutName: String) -> URL? {
        let name = shortcutName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "shortcuts"
        components.host = "x-callback-url"
        components.path = "/run-shortcut"
        components.queryItems = [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "x-success", value: "\(callbackScheme)://shortcut/done"),
            URLQueryItem(name: "x-cancel", value: "\(callbackScheme)://shortcut/cancel"),
            URLQueryItem(name: "x-error", value: "\(callbackScheme)://shortcut/error"),
        ]
        // URLComponents leaves ":" and "/" in query values; Shortcuts needs the
        // callback URLs fully encoded.
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: ":/?&=+")
        components.percentEncodedQueryItems = components.queryItems?.map {
            URLQueryItem(name: $0.name, value: $0.value?.addingPercentEncoding(withAllowedCharacters: allowed))
        }
        return components.url
    }

    /// Reads a callback URL from Shortcuts, nil for any other URL.
    static func result(from url: URL) -> Result? {
        guard url.scheme == callbackScheme, url.host == "shortcut" else { return nil }
        return Result(rawValue: url.lastPathComponent)
    }
}
