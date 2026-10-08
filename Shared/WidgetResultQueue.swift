import Foundation

/// Ein vom Widget verbuchtes Ergebnis, das noch in den SwiftData-Store eingespielt
/// werden muss. Die Widget-Extension kann die DB nicht erreichen (app-lokaler,
/// `.complete`-geschützter Store, eigener Sandbox-Prozess – siehe [[PersistenceController]]),
/// deshalb legt der [[RegisterWidgetResultIntent]] das Ergebnis hier ab und die App spielt
/// es beim nächsten Vordergrund-Wechsel ein (siehe [[WidgetResultReconciler]]).
struct PendingWidgetResult: Codable, Equatable {
    let wordID: UUID
    let correct: Bool
    /// Zeitpunkt des Tipps. Wird an `Vocab.registerResult(now:)` durchgereicht, damit die
    /// Pro-Kalendertag-Zählung am tatsächlichen Antwortzeitpunkt hängt, nicht am (evtl. viel
    /// späteren) App-Start.
    let date: Date
}

/// Dateibasierte Warteschlange im App-Group-Container, über die das interaktive Widget
/// „Gewusst"/„Nochmal"-Ergebnisse an die App übergibt. Bewusst analog zu [[WidgetSnapshot]]
/// aufgebaut (gleiche App-Group, gleiche Datenschutz-Stufe), damit beide Prozesse – auch bei
/// gesperrtem Gerät – zuverlässig lesen/schreiben können.
enum WidgetResultQueue {

    /// Speicherort der Queue im gemeinsamen Container.
    static var url: URL {
        AppGroup.containerURL.appendingPathComponent("widget_results.json")
    }

    /// Obergrenze der gepufferten Ergebnisse. Mehr als das kann sich praktisch nie ansammeln
    /// (die App drained bei jedem Vordergrund-Wechsel); die Kappung ist nur ein Sicherheitsnetz
    /// gegen unbegrenztes Wachstum, falls die App ungewöhnlich lange nicht geöffnet wird.
    static let maxCount = 200

    /// Gleiche Schutzstufe wie der Widget-Snapshot (Issue #104): ausdrücklich NICHT `.complete`,
    /// damit das Lock-Screen-Widget auch bei GESPERRTEM Gerät schreiben kann.
    static let writeOptions: Data.WritingOptions = [.atomic, .completeFileProtectionUntilFirstUserAuthentication]

    /// Lädt die gepufferten Ergebnisse. Fehlt die Datei oder ist sie beschädigt, gilt die
    /// Queue als leer (toleranter Decoder, analog zu [[WidgetSnapshot]] `load`).
    static func load() -> [PendingWidgetResult] {
        guard let data = try? Data(contentsOf: url),
              let results = try? JSONDecoder.queue.decode([PendingWidgetResult].self, from: data)
        else { return [] }
        return results
    }

    /// Hängt ein Ergebnis an und schreibt die Queue zurück (lädt vorher den aktuellen Stand,
    /// damit mehrere Tipps nacheinander nicht verloren gehen). Wird aus dem Widget-Prozess
    /// aufgerufen.
    ///
    /// Hinweis zum prozessübergreifenden Race: App (drain) und Widget (append) greifen auf
    /// dieselbe Datei zu. Ein Append exakt zwischen `load` und `clear` der App kann in seltenen
    /// Fällen verloren gehen (last-writer-wins). Für ein P3-Komfort-Feature ist das akzeptabel –
    /// das Wort wird dann schlicht beim nächsten Üben/Tipp verbucht.
    static func append(_ result: PendingWidgetResult) {
        var results = load()
        results.append(result)
        if results.count > maxCount {
            results.removeFirst(results.count - maxCount)
        }
        save(results)
    }

    /// Leert die Queue (von der App nach dem Einspielen aufgerufen).
    static func clear() {
        try? FileManager.default.removeItem(at: url)
    }

    private static func save(_ results: [PendingWidgetResult]) {
        guard let data = try? JSONEncoder.queue.encode(results) else { return }
        try? data.write(to: url, options: writeOptions)
    }
}

private extension JSONEncoder {
    static let queue: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}

private extension JSONDecoder {
    static let queue: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
