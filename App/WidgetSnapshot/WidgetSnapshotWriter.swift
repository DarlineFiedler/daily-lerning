import Foundation
import SwiftData
import WidgetKit

/// Schreibt den aktuellen Stand der aktivierten Widget-Wörter + Einstellungen als
/// JSON-Snapshot in den App-Group-Container und lädt das Widget neu.
/// Aufzurufen, wann immer sich aktivierte Wörter oder Widget-Einstellungen ändern.
enum WidgetSnapshotWriter {

    @MainActor
    static func refresh(context: ModelContext) {
        let snapshot = WidgetSnapshot(
            words: widgetWords(context: context),
            settings: WidgetSettingsStore.current,
            generatedAt: .now
        )
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Wählt die im Widget anzuzeigenden Wörter aus: bevorzugt die ausdrücklich
    /// per Stern markierten. Ist keines markiert, fällt es auf den gesamten
    /// Wortschatz zurück – so rotiert das Widget durch alle Vokabeln, statt
    /// „No words" zu zeigen. Reine Auswahl ohne Seiteneffekte (testbar).
    @MainActor
    static func widgetWords(context: ModelContext) -> [WidgetWord] {
        let starred = FetchDescriptor<Vocab>(
            predicate: #Predicate { $0.includeInWidget == true },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        var vocabs = (try? context.fetch(starred)) ?? []

        if vocabs.isEmpty {
            let all = FetchDescriptor<Vocab>(sortBy: [SortDescriptor(\.createdAt)])
            vocabs = (try? context.fetch(all)) ?? []
        }

        return vocabs.map { WidgetWord(id: $0.id, word: $0.word, meaning: $0.meaning) }
    }
}
