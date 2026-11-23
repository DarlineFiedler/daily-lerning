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

    /// Läuft nur ein flüchtiger Notfall-Store (Store-Open fehlgeschlagen, siehe
    /// [[PersistenceController]] `storeOpenFailed`)? Als Closure, damit Tests den Zustand
    /// injizieren können, ohne das (bewusst `private(set)`) Flag selbst zu verändern.
    static var isStoreVolatile: () -> Bool = { PersistenceController.storeOpenFailed }

    /// Nach einer Vokabel-Änderung: aktiven Wortbestand einmal laden und daraus
    /// Widget-Snapshot und Badge ableiten.
    ///
    /// Bei flüchtigem Store (Issue #163) wird NICHTS aufgefrischt: Der Wegwerf-Store würde
    /// den intakten Widget-Snapshot und das Badge mit Daten überschreiben, die beim nächsten
    /// Start verschwunden sind. Gibt zurück, ob aufgefrischt wurde.
    @discardableResult
    static func afterVocabChange(context: ModelContext) -> Bool {
        guard !isStoreVolatile() else { return false }
        let active = activeVocabs(context: context)
        WidgetSnapshotWriter.refresh(activeVocabs: active)
        BadgeUpdater.refresh(activeVocabs: active)
        return true
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
        // Bei fehlgeschlagenem Store-Open läuft nur ein flüchtiger, LEERER In-Memory-Store
        // (siehe [[PersistenceController]] `storeOpenFailed`). Dann NICHTS auffrischen: Ein
        // Drain würde die Widget-Queue leeren und die Ergebnisse in den Wegwerf-Store buchen
        // (dauerhaft verloren), und `afterVocabChange` würde den intakten Widget-Snapshot mit
        // einem leeren überschreiben. Die echten Daten auf der Platte bleiben so unangetastet.
        guard !isStoreVolatile() else { return }
        // Zuerst die vom interaktiven Widget verbuchten „Gewusst"/„Nochmal"-Ergebnisse
        // einspielen (siehe [[WidgetResultReconciler]]). Das läuft bei JEDEM Vordergrund-
        // Wechsel – unabhängig vom Kalendertag-Guard unten –, weil die Nutzerin das Widget
        // auch mehrfach am selben Tag getippt haben kann. Wurde etwas verbucht, muss trotz
        // gleichem Tag voll aufgefrischt werden (der geänderte Status bewegt das Badge).
        let didReconcile = WidgetResultReconciler.drain(context: context)
        // Ein reiner Widget-Tag kann das Wochenziel erreicht haben, ohne dass je eine
        // `registerSession` lief – darum hier explizit prüfen/verbuchen (idempotent).
        if didReconcile {
            AchievementService.checkWeeklyGoalReached(context: context, on: now)
            // Ansichten mit gecachtem Aktivitäts-/Challenge-Snapshot (Garten-Tab, #169)
            // informieren – synchron NACH dem Drain, damit sie die frisch geschriebenen Werte
            // lesen. Ein eigener `scenePhase`-Handler dort liefe in unbestimmter Reihenfolge.
            NotificationCenter.default.post(name: .widgetResultsReconciled, object: nil)
        }
        guard didReconcile || shouldRefreshOnActive(lastRefreshDay: lastActiveRefreshDay, now: now) else { return }
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

extension Notification.Name {
    /// Gepostet von [[AppContentRefresh]] `onAppActive`, nachdem Widget-Ergebnisse in Store,
    /// Aktivitäts-Log und Challenge verbucht wurden (auf dem Main-Thread).
    static let widgetResultsReconciled = Notification.Name("AppContentRefresh.widgetResultsReconciled")
}
