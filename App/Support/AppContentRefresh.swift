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

    /// Kalendertag des letzten Vordergrund-Refreshes. Prozess-lokal & flüchtig (analog zu
    /// [[WidgetSnapshotWriter]] `lastWritten`): nach einem Kaltstart `nil`, sodass der erste
    /// `onAppActive` immer durchläuft und Widget/Badge garantiert frisch sind.
    ///
    /// **Invariante, auf der das Überspringen beruht:** Vokabeln ändern sich nur im
    /// Vordergrund (lokaler SwiftData-Store, KEIN CloudKit/Hintergrund-Sync – siehe
    /// [[PersistenceController]]). Käme je eine Hintergrund-Mutation dazu (CloudKit-Sync,
    /// `BGTaskScheduler`), muss dieses Tag neu überdacht werden.
    private static var lastActiveRefreshDay: Date?

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
    ///
    /// Beim **reinen App-Switch** (gleicher Kalendertag, schon einmal aufgefrischt) kann sich
    /// seit dem letzten Refresh nichts geändert haben: Vokabeln und Widget-Einstellungen ändern
    /// sich nur im Vordergrund (dort wird direkt via `afterVocabChange`/`refresh` aufgefrischt),
    /// und der einzige zeitabhängige Faktor ist der Tageswechsel (`DailyPlan` ist tagesbasiert).
    /// Deshalb wird dann der sonst nutzlose Fetch + Badge- + Streak-Reload übersprungen.
    static func onAppActive(context: ModelContext, now: Date = .now) {
        guard shouldRefreshOnActive(lastRefreshDay: lastActiveRefreshDay, now: now) else { return }
        lastActiveRefreshDay = Calendar.current.startOfDay(for: now)
        afterVocabChange(context: context)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.streak)
    }

    /// Entscheidet, ob beim Vordergrund-Wechsel voll aufgefrischt werden muss: nur beim ersten
    /// Aufruf (`lastRefreshDay == nil`) oder bei einem Tageswechsel seit dem letzten Refresh.
    /// Reine Funktion ohne Seiteneffekte – Kern der No-Op-Vermeidung.
    static func shouldRefreshOnActive(lastRefreshDay: Date?, now: Date = .now) -> Bool {
        lastRefreshDay != Calendar.current.startOfDay(for: now)
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
