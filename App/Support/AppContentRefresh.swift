import Foundation
import SwiftData
import WidgetKit

/// Gemeinsamer Einstieg, um nach einer Vokabel-Änderung Widget-Snapshot **und**
/// App-Icon-Badge zu aktualisieren. Bündelt den Zugriff auf den aktiven Wortbestand in
/// **einen** Fetch, statt dass [[WidgetSnapshotWriter]] und [[BadgeUpdater]] je einen
/// eigenen Full-Fetch über alle `Vocab` machen (heißer Pfad: Stern-Toggle, Löschen,
/// Status setzen, Import …).
@MainActor
enum AppContentRefresh {

    /// Nach einer Vokabel-Änderung: aktiven Wortbestand einmal laden und daraus
    /// Widget-Snapshot und Badge ableiten.
    static func afterVocabChange(context: ModelContext) {
        let active = activeVocabs(context: context)
        WidgetSnapshotWriter.refresh(activeVocabs: active)
        BadgeUpdater.refresh(activeVocabs: active)
    }

    /// Wie `afterVocabChange`, aber zusätzlich beim App-Start / Vordergrund-Wechsel: Da
    /// Zeit vergangen sein kann (Tageswechsel), auch das Streak-Widget auffrischen – so
    /// bleibt das bisherige `reloadAllTimelines()`-Verhalten an diesen Stellen erhalten.
    static func onAppActive(context: ModelContext) {
        afterVocabChange(context: context)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.streak)
    }

    /// Aktive (nicht archivierte) Wörter, nach Anlagedatum sortiert. Wörter aus
    /// archivierten Gruppen sind „pausiert" und gehören weder aufs Widget noch ins Badge.
    /// Die Traversierung der optionalen `group`-Beziehung ist im `#Predicate` heikel,
    /// daher nach dem Fetch in Swift filtern.
    static func activeVocabs(context: ModelContext) -> [Vocab] {
        let all = (try? context.fetch(
            FetchDescriptor<Vocab>(sortBy: [SortDescriptor(\.createdAt)])
        )) ?? []
        return all.filter { $0.group?.isArchived != true }
    }
}
