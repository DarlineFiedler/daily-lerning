import AppIntents
import WidgetKit

/// AppIntent hinter den „Gewusst"/„Nochmal"-Buttons des Wort-Widgets (iOS 17 interaktive
/// Widgets). Läuft im Widget-Extension-Prozess, der die SwiftData-DB nicht erreichen kann –
/// deshalb legt er das Ergebnis nur in die [[WidgetResultQueue]] (App-Group) und lädt das
/// Widget neu; die App verbucht es beim nächsten Vordergrund-Wechsel per
/// [[WidgetResultReconciler]]. Liegt bewusst im geteilten Target (`Shared`, in App UND
/// Widget kompiliert) und referenziert kein `Vocab`, damit die Extension von SwiftData
/// entkoppelt bleibt.
struct RegisterWidgetResultIntent: AppIntent {
    static var title: LocalizedStringResource = "Register widget result"
    /// Nicht in der Shortcuts-App anbieten – der Intent ergibt nur als Widget-Button Sinn.
    static var isDiscoverable = false

    /// UUID des Worts als String (AppIntent-Parameter unterstützen kein nacktes `UUID`).
    @Parameter(title: "Word ID") var wordID: String
    /// `true` = „Gewusst", `false` = „Nochmal".
    @Parameter(title: "Correct") var correct: Bool

    init() {}

    init(wordID: UUID, correct: Bool) {
        self.wordID = wordID.uuidString
        self.correct = correct
    }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: wordID) {
            WidgetResultQueue.append(PendingWidgetResult(wordID: id, correct: correct, date: Date()))
        }
        // Nur das Wort-Widget neu laden – so zeigt die gerade beantwortete Karte sofort ihre
        // Bestätigung (siehe [[VocabTimelineProvider]]).
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.vocab)
        return .result()
    }
}
