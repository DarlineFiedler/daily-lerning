import Foundation

/// Ein einzelnes Wort, das im Lock-Screen-Widget angezeigt werden kann.
struct WidgetWord: Codable, Identifiable, Hashable {
    let id: UUID
    let word: String        // Lernsprache (z.B. Hangul)
    let meaning: String     // Muttersprache
}

/// Vom Widget geteilte Einstellungen.
struct WidgetSettings: Codable, Hashable {
    /// Wechsel-Intervall in Minuten (10, 15, 30, 60, 120).
    var intervalMinutes: Int = 30
    /// Bedeutung dauerhaft anzeigen.
    var showMeaning: Bool = true
    /// Bedeutung erst nach Tippen anzeigen (öffnet die App per Deep-Link).
    var showMeaningOnTap: Bool = false

    static let intervalOptions = [10, 15, 30, 60, 120]
}

/// Vollständiger Snapshot, den die App in den App-Group-Container schreibt
/// und den die Widget-Extension liest. Entkoppelt das Widget von SwiftData.
struct WidgetSnapshot: Codable {
    var words: [WidgetWord]
    var settings: WidgetSettings
    var generatedAt: Date

    static let empty = WidgetSnapshot(words: [], settings: WidgetSettings(), generatedAt: .now)

    /// Lädt den Snapshot aus dem gemeinsamen Container (vom Widget genutzt).
    static func load() -> WidgetSnapshot {
        guard let data = try? Data(contentsOf: AppGroup.snapshotURL),
              let snapshot = try? JSONDecoder.snapshot.decode(WidgetSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }

    /// Schreibt den Snapshot in den gemeinsamen Container (von der App genutzt).
    func save() {
        guard let data = try? JSONEncoder.snapshot.encode(self) else { return }
        try? data.write(to: AppGroup.snapshotURL, options: .atomic)
    }
}

private extension JSONEncoder {
    static let snapshot: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}

private extension JSONDecoder {
    static let snapshot: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
