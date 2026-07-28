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

    /// Beendet die Live Activity einer **abgeschlossenen** Session, lässt sie aber als
    /// `active` bestehen. So bleibt im „Heute"-Fluss die Zusammenfassung (Genauigkeit,
    /// Streak, „Falsche wiederholen") sichtbar; freigegeben wird die Session erst beim
    /// tatsächlichen Schließen über `finish`.
    func complete(_ session: PracticeSession) {
        guard tracked === session else { return }
        stopActivity()
        tracked = nil
    }

    /// Räumt die Session beim Schließen vollständig ab: Live Activity beenden und die
    /// Session freigeben (ein Deep-Link führt danach nicht mehr zurück). Ohne Argument
    /// beendet es die gerade aktive/getrackte Session; mit Argument nur, wenn es dieselbe
    /// ist (auch nachdem `complete` das Tracking bereits gelöst hat).
    func finish(_ session: PracticeSession? = nil) {
        if let session, active !== session, tracked !== session { return }
        stopActivity()
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
        stopActivity() // keine „hängende" Activity aus einer früheren Session offen lassen
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

    private func stopActivity() {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
