import Foundation

/// Deep-Links aus dem Widget: `dailyhangul://word/<uuid>`.
/// Liegt in Shared, damit App und Widget-Extension es nutzen können.
enum DeepLink {
    static func wordURL(id: UUID) -> URL {
        URL(string: "\(AppGroup.urlScheme)://word/\(id.uuidString)")!
    }

    static func wordID(from url: URL) -> UUID? {
        guard url.scheme == AppGroup.urlScheme, url.host == "word" else { return nil }
        return UUID(uuidString: url.lastPathComponent)
    }
}
