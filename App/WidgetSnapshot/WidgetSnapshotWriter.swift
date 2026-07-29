import Foundation
import SwiftData
import WidgetKit

/// Schreibt den aktuellen Stand der aktivierten Widget-Wörter + Einstellungen als
/// JSON-Snapshot in den App-Group-Container und lädt das Widget neu.
/// Aufzurufen, wann immer sich aktivierte Wörter oder Widget-Einstellungen ändern.
enum WidgetSnapshotWriter {

    /// Inhalt (Wörter + Einstellungen, OHNE `generatedAt`) des zuletzt geschriebenen
    /// Snapshots. Ist der Inhalt unverändert, sparen wir Datei-Write und Widget-Reload.
    /// Bewusst der **exakte** Inhalt statt eines Hashes: Ein Hash-Kollision würde ein
    /// echtes Update verschlucken (stale Widget) – bei einem 64-Bit-Hash extrem
    /// unwahrscheinlich, aber vermeidbar, da `WidgetWord`/`WidgetSettings` ohnehin
    /// `Equatable` sind. Prozess-lokal & flüchtig: nach einem (Kalt-)Start ist er `nil`,
    /// sodass der erste Refresh immer schreibt und das Widget garantiert frisch ist.
    private struct WrittenContent: Equatable {
        let words: [WidgetWord]
        let settings: WidgetSettings
    }

    private static var lastWritten: WrittenContent?

    /// Schreibt den Snapshot aus einem bereits geladenen, aktiven Wortbestand und lädt –
    /// nur bei tatsächlicher Änderung – gezielt das Vokabel-Widget neu. Der Aufrufer
    /// (siehe [[AppContentRefresh]]) fetcht die Wörter einmal und teilt sie mit dem Badge.
    /// Gibt zurück, ob tatsächlich geschrieben wurde (`false` = redundanter Refresh
    /// übersprungen).
    @MainActor
    @discardableResult
    static func refresh(activeVocabs: [Vocab]) -> Bool {
        let content = WrittenContent(
            words: widgetWords(among: activeVocabs),
            settings: WidgetSettingsStore.current
        )
        guard content != lastWritten else { return false }
        lastWritten = content

        WidgetSnapshot(words: content.words, settings: content.settings, generatedAt: .now).save()
        // Nur das Wort-Widget neu laden – das Streak-Widget hängt nicht am Snapshot
        // (siehe [[AppGroup]] `WidgetKind`), spart einen unnötigen Reload.
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.vocab)
        return true
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
