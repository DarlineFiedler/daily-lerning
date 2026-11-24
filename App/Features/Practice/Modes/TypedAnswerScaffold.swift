import SwiftUI

/// Gemeinsames Gerüst der Eintipp-Modi (Schreiben, Lückentext): Aufgabenkarte,
/// Eingabefeld, „Prüfen"/„Weiß ich nicht", Ergebnis-Banner und die Aktions-Buttons.
///
/// Die Modi liefern nur, was sich unterscheidet: die Aufgabenkarte, die Bewertung der
/// Eingabe und den Banner-Inhalt. Nach dem Prüfen gilt:
/// - voll richtig → nur „Weiter" (zählt richtig),
/// - aufgegeben → nur „Weiter" (zählt falsch, kein „Trotzdem richtig" – es gab keine Eingabe),
/// - sonst → „Trotzdem richtig" oder „Weiter".
struct TypedAnswerScaffold<Prompt: View, BannerContent: View>: View {
    private let placeholder: String
    private let underline: Color
    private let bannerTint: Color
    private let evaluate: (String) -> Bool
    private let onGiveUp: () -> Void
    private let onAnswer: (Bool) -> Void
    private let prompt: Prompt
    private let bannerContent: BannerContent

    @State private var typed = ""
    @State private var checked = false
    @State private var wasCorrect = false
    @State private var gaveUp = false
    @FocusState private var focused: Bool

    /// - Parameters:
    ///   - evaluate: bewertet die Eingabe; `true` heißt „voll richtig".
    ///   - onGiveUp: setzt den modus-eigenen Bewertungszustand auf „falsch" zurück.
    init(placeholder: String,
         underline: Color,
         bannerTint: Color,
         evaluate: @escaping (String) -> Bool,
         onGiveUp: @escaping () -> Void,
         onAnswer: @escaping (Bool) -> Void,
         @ViewBuilder prompt: () -> Prompt,
         @ViewBuilder bannerContent: () -> BannerContent) {
        self.placeholder = placeholder
        self.underline = underline
        self.bannerTint = bannerTint
        self.evaluate = evaluate
        self.onGiveUp = onGiveUp
        self.onAnswer = onAnswer
        self.prompt = prompt()
        self.bannerContent = bannerContent()
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            prompt

            TextField(placeholder, text: $typed)
                .font(.appDisplay(30, weight: .regular))
                .multilineTextAlignment(.center)
                .tint(Theme.vermillion)
                .padding(.vertical, Theme.Spacing.s)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(underline).frame(height: 2)
                }
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($focused)
                .disabled(checked)
                // Return mit leerem Feld prüft nicht – Fokus zurückholen, damit die Tastatur
                // bleibt. Erst im nächsten Runloop: während `onSubmit` gibt das Feld den Fokus
                // gerade ab, ein synchrones `focused = true` würde SwiftUI ignorieren.
                .onSubmit {
                    guard !checked else { return }
                    if canCheck {
                        check()
                    } else {
                        DispatchQueue.main.async { focused = true }
                    }
                }

            if checked {
                resultBanner
                actionButtons
            } else {
                Button(action: check) {
                    Label(L("practice.check"), systemImage: "checkmark")
                }
                .buttonStyle(.primary)
                .disabled(!canCheck)

                // Aufgeben ist bewusst NICHT an eine Eingabe gebunden – weiß man das Wort
                // gar nicht, zeigt der Button direkt die Lösung (zählt als falsch).
                Button(action: giveUp) {
                    Label(L("practice.iDontKnow"), systemImage: "questionmark.circle")
                }
                .buttonStyle(.secondary(tint: Theme.wrong))
            }
        }
        .onAppear { focused = true }
    }

    private var resultBanner: some View {
        VStack(spacing: 6) {
            bannerContent
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.m)
        .background(bannerTint.opacity(0.14),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
    }

    @ViewBuilder
    private var actionButtons: some View {
        if wasCorrect || gaveUp {
            // Richtig → weiter (richtig); aufgegeben → nur weiter (falsch).
            Button { onAnswer(wasCorrect) } label: {
                Label(L("common.next"), systemImage: "arrow.right")
            }
            .buttonStyle(.primary)
        } else {
            VStack(spacing: Theme.Spacing.s) {
                Button { onAnswer(true) } label: {
                    Label(L("practice.markCorrect"), systemImage: "hand.thumbsup")
                }
                .buttonStyle(.secondary(tint: LearningStatus.learned.color))

                Button { onAnswer(false) } label: {
                    Label(L("common.next"), systemImage: "arrow.right")
                }
                .buttonStyle(.primary)
            }
        }
    }

    /// Prüfen erst mit echter Eingabe – gilt für Button und Return-Taste gleichermaßen,
    /// sonst würde ein leeres Feld als falsch gewertet (mit „Trotzdem richtig").
    private var canCheck: Bool {
        !typed.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func check() {
        wasCorrect = evaluate(typed)
        withAnimation { checked = true }
        focused = false
    }

    /// „Weiß ich nicht": Lösung als falsch enthüllen, ohne dass eine Eingabe nötig war.
    private func giveUp() {
        wasCorrect = false
        gaveUp = true
        onGiveUp()
        withAnimation { checked = true }
        focused = false
    }
}
