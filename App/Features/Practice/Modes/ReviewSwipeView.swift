import SwiftUI

/// Modus 2: Durchgehen. Zuerst wird die Antwort aufgedeckt (Tippen / „Antwort
/// zeigen"), erst danach bewertet man sich ehrlich selbst: „Wusste ich" /
/// „Wusste ich nicht". So kann man sich nicht als „gewusst" markieren, ohne die
/// Lösung gesehen zu haben.
struct ReviewSwipeView: View {
    let item: PracticeItem
    let onAnswer: (Bool) -> Void

    @State private var revealed = false

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            card
                .onTapGesture { reveal() }

            if revealed {
                HStack(spacing: Theme.Spacing.s + 4) {
                    Button { onAnswer(false) } label: {
                        Label(L("practice.iDontKnow"), systemImage: "xmark")
                    }
                    .buttonStyle(.secondary(tint: Theme.wrong))

                    Button { onAnswer(true) } label: {
                        Label(L("practice.iKnow"), systemImage: "checkmark")
                    }
                    .buttonStyle(.primary)
                }
            } else {
                Text(L("practice.tapToReveal"))
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                Button { reveal() } label: {
                    Label(L("practice.showAnswer"), systemImage: "eye")
                }
                .buttonStyle(.primary)
            }
        }
    }

    private var card: some View {
        VStack(spacing: Theme.Spacing.m) {
            HStack(spacing: Theme.Spacing.s) {
                Text(item.prompt())
                    .font(.appDisplay(44))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                if item.direction == .wordToMeaning {
                    SpeakButton(text: item.vocab.word, font: .appTitle2, tint: .white)
                }
            }
            if revealed {
                Divider().overlay(.white.opacity(0.4))
                HStack(spacing: Theme.Spacing.s) {
                    Text(item.answer())
                        .font(.appTitle2)
                        .opacity(0.95)
                        .minimumScaleFactor(0.5)
                    if item.direction == .meaningToWord {
                        SpeakButton(text: item.vocab.word, font: .appTitle3, tint: .white)
                    }
                }
                if let example = item.vocab.example, !example.isEmpty {
                    Text(example)
                        .font(.appBody)
                        .opacity(0.8)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl + 16)
        .padding(.horizontal, Theme.Spacing.m)
        .background(Theme.brandGradientSoft, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .foregroundStyle(.white)
        .shadow(color: Theme.brandStart.opacity(0.3), radius: 16, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityHint(revealed ? "" : L("practice.tapToReveal"))
    }

    private func reveal() {
        guard !revealed else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { revealed = true }
    }
}
