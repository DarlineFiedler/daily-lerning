import Foundation

/// Deep-Links aus Widget und Notifications:
/// `dailyhangul://word/<uuid>` (einzelnes Wort) und `dailyhangul://review` (Wiederholung).
/// Liegt in Shared, damit App und Widget-Extension es nutzen können.
enum DeepLink {
    static func wordURL(id: UUID) -> URL {
        URL(string: "\(AppGroup.urlScheme)://word/\(id.uuidString)")!
    }

    static func wordID(from url: URL) -> UUID? {
        guard url.scheme == AppGroup.urlScheme, url.host == "word" else { return nil }
        return UUID(uuidString: url.lastPathComponent)
    }

    /// Startet die fällige Wiederholung (z.B. aus der Tages-Erinnerung).
    static var reviewURL: URL {
        URL(string: "\(AppGroup.urlScheme)://review")!
    }

    static func isReview(_ url: URL) -> Bool {
        url.scheme == AppGroup.urlScheme && url.host == "review"
    }
}
