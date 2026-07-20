import Foundation
import SwiftData
import WidgetKit

/// Schreibt den aktuellen Stand der aktivierten Widget-Wörter + Einstellungen als
/// JSON-Snapshot in den App-Group-Container und lädt das Widget neu.
/// Aufzurufen, wann immer sich aktivierte Wörter oder Widget-Einstellungen ändern.
enum WidgetSnapshotWriter {

    @MainActor
    static func refresh(context: ModelContext) {
        let descriptor = FetchDescriptor<Vocab>(
            predicate: #Predicate { $0.includeInWidget == true },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        var vocabs = (try? context.fetch(descriptor)) ?? []

        // Fallback: Hat der Nutzer noch kein Wort ausdrücklich fürs Widget markiert
        // (Stern), zeigen wir statt „No words" einfach alle vorhandenen Vokabeln –
        // das Widget rotiert dann durch den gesamten Wortschatz.
        if vocabs.isEmpty {
            let allDescriptor = FetchDescriptor<Vocab>(
                sortBy: [SortDescriptor(\.createdAt)]
            )
            vocabs = (try? context.fetch(allDescriptor)) ?? []
        }

        let words = vocabs.map { WidgetWord(id: $0.id, word: $0.word, meaning: $0.meaning) }

        let snapshot = WidgetSnapshot(
            words: words,
            settings: WidgetSettingsStore.current,
            generatedAt: .now
        )
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
