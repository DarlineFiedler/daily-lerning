import ActivityKit
import Foundation

/// Hält die aktuell laufende Lernsession auf App-Ebene und steuert die zugehörige
/// Live Activity (Start/Update/Ende). App-weit über `.environment` injiziert, damit
/// ein Deep-Link (`dailyhangul://session`) aus der Live Activity die **echte**,
/// laufende Session wiederfindet, statt eine neue zu starten.
///
/// Alle ActivityKit-Aufrufe sind hier gebündelt; `PracticeSession` selbst bleibt frei
/// davon (damit Unit-Tests keine Live Activity auslösen).
@MainActor
@Observable
final class ActiveSessionStore {
    /// Session, in die ein Deep-Link zurückführen soll (nur der „Heute"-Fluss ist so
    /// wieder-präsentierbar; der Gruppen-Fluss läuft in der Navigation weiter).
    private(set) var active: PracticeSession?

    /// Session, deren Live Activity aktuell läuft.
    private var tracked: PracticeSession?
    private var activity: Activity<PracticeActivityAttributes>?

    /// Startet die Live Activity für eine beginnende Session. `resumable` markiert den
    /// „Heute"-Fluss, der aus der Live Activity heraus wieder-präsentiert werden kann.
    func begin(_ session: PracticeSession, resumable: Bool) {
        guard tracked !== session else { return }
        tracked = session
        if resumable { active = session }
        startActivity(for: session)
    }

    /// Aktualisiert den Fortschritt der Live Activity nach einer beantworteten Karte.
    func refresh(_ session: PracticeSession) {
        guard tracked === session else { return }
        let state = state(for: session)
        Task { await update(state: state) }
    }

    /// Beendet die Live Activity und gibt die Session frei. Ohne Argument beendet es die
    /// gerade getrackte Session; mit Argument nur, wenn es dieselbe ist.
    func finish(_ session: PracticeSession? = nil) {
        if let session, tracked !== session { return }
        endActivity()
        tracked = nil
        active = nil
    }

    // MARK: - ActivityKit

    private func state(for session: PracticeSession) -> PracticeActivityAttributes.ContentState {
        .init(total: session.total, position: session.position,
              correct: session.correctCount, wrong: session.wrongCount)
    }

    private func startActivity(for session: PracticeSession) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled, session.total > 0 else { return }
        endActivity() // keine „hängende" Activity aus einer früheren Session offen lassen
        let content = ActivityContent(state: state(for: session), staleDate: nil)
        activity = try? Activity.request(
            attributes: PracticeActivityAttributes(),
            content: content,
            pushType: nil
        )
    }

    private func update(state: PracticeActivityAttributes.ContentState) async {
        guard let activity else { return }
        await activity.update(ActivityContent(state: state, staleDate: nil))
    }

    private func endActivity() {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
