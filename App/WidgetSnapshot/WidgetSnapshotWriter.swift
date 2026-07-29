import Foundation
import SwiftData
import WidgetKit

/// Schreibt den aktuellen Stand der aktivierten Widget-Wörter + Einstellungen als
/// JSON-Snapshot in den App-Group-Container und lädt das Widget neu.
/// Aufzurufen, wann immer sich aktivierte Wörter oder Widget-Einstellungen ändern.
enum WidgetSnapshotWriter {

    /// Signatur (Wörter + Einstellungen, OHNE `generatedAt`) des zuletzt geschriebenen
    /// Snapshots. Ändert sich der Inhalt nicht, sparen wir Datei-Write und Widget-Reload.
    /// Prozess-lokal & flüchtig: nach einem (Kalt-)Start ist sie `nil`, sodass der erste
    /// Refresh immer schreibt und das Widget garantiert frisch ist.
    private static var lastSignature: Int?

    /// Schreibt den Snapshot aus einem bereits geladenen, aktiven Wortbestand und lädt –
    /// nur bei tatsächlicher Änderung – gezielt das Vokabel-Widget neu. Der Aufrufer
    /// (siehe [[AppContentRefresh]]) fetcht die Wörter einmal und teilt sie mit dem Badge.
    @MainActor
    static func refresh(activeVocabs: [Vocab]) {
        let words = widgetWords(among: activeVocabs)
        let settings = WidgetSettingsStore.current

        var hasher = Hasher()
        hasher.combine(words)
        hasher.combine(settings)
        let signature = hasher.finalize()
        guard signature != lastSignature else { return }
        lastSignature = signature

        WidgetSnapshot(words: words, settings: settings, generatedAt: .now).save()
        // Nur das Wort-Widget neu laden – das Streak-Widget hängt nicht am Snapshot
        // (siehe [[AppGroup]] `WidgetKind`), spart einen unnötigen Reload.
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.vocab)
    }

    /// Wählt die im Widget anzuzeigenden Wörter aus einer bereits gefilterten, aktiven
    /// Wortliste: bevorzugt die ausdrücklich per Stern markierten. Ist keines markiert,
    /// fällt es auf den gesamten (aktiven) Wortschatz zurück – so rotiert das Widget durch
    /// alle Vokabeln, statt „No words" zu zeigen. Reine Auswahl ohne Seiteneffekte.
    static func widgetWords(among activeVocabs: [Vocab]) -> [WidgetWord] {
        let starred = activeVocabs.filter(\.includeInWidget)
        let chosen = starred.isEmpty ? activeVocabs : starred
        return chosen.map { WidgetWord(id: $0.id, word: $0.word, meaning: $0.meaning) }
    }

    /// Test-/Convenience-Einstieg: lädt den aktiven Wortbestand selbst und wählt daraus die
    /// Widget-Wörter. Produktivpfad nutzt `widgetWords(among:)` mit geteiltem Fetch.
    @MainActor
    static func widgetWords(context: ModelContext) -> [WidgetWord] {
        widgetWords(among: AppContentRefresh.activeVocabs(context: context))
    }
}
