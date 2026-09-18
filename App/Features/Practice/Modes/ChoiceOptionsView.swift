import SwiftUI

/// Die vier Antwort-Optionen samt Auswahl-/Feedback-Logik. Geteilt von
/// Multiple Choice und Hör-Modus – der einzige Unterschied dieser Modi ist der
/// Prompt (Text vs. Audio), die Optionen sind identisch.
///
/// Papier-Optik (Screen 1b): neutrale Karten (#FBF5EA, 1px Rahmen, harter Schatten);
/// nach der Wahl wird die richtige grün, die falsch gewählte zinnoberrot getönt, alle
/// übrigen auf 50 % Deckkraft ohne Schatten.
struct ChoiceOptionsView: View {
    let item: PracticeItem
    @Binding var selected: Vocab?

    private var answered: Bool { selected != nil }

    var body: some View {
        VStack(spacing: Theme.Spacing.s + 4) {
            ForEach(item.choices) { choice in
                Button {
                    if !answered { selected = choice }
                } label: {
                    HStack {
                        Text(item.optionText(choice))
                            .font(.appBody)
                            .foregroundStyle(textColor(for: choice))
                            .multilineTextAlignment(.leading)
                        Spacer()
                        if answered, let mark = mark(for: choice) {
                            Text(mark.symbol)
                                .font(.appHeadline)
                                .foregroundStyle(mark.color)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.Spacing.m)
                    .background(background(for: choice), in: RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                            .strokeBorder(border(for: choice), lineWidth: 1.5)
                    )
                    .modifier(OptionShadow(active: showsShadow(for: choice)))
                    .opacity(faded(choice) ? 0.5 : 1)
                }
                .buttonStyle(.plain)
                .disabled(answered)
            }
        }
    }

    private func isRight(_ choice: Vocab) -> Bool { choice.id == item.vocab.id }
    private func isChosen(_ choice: Vocab) -> Bool { choice.id == selected?.id }

    /// Übrige (nicht richtige, nicht gewählte) Optionen verblassen nach der Antwort.
    private func faded(_ choice: Vocab) -> Bool {
        answered && !isRight(choice) && !isChosen(choice)
    }

    private func showsShadow(for choice: Vocab) -> Bool {
        !answered || isRight(choice) || isChosen(choice)
    }

    private func mark(for choice: Vocab) -> (symbol: String, color: Color)? {
        if isRight(choice) { return ("✓", Theme.leaf) }
        if isChosen(choice) { return ("✕", Theme.vermillion) }
        return nil
    }

    private func textColor(for choice: Vocab) -> Color {
        guard answered else { return Theme.ink }
        if isRight(choice) { return Theme.leafText }
        if isChosen(choice) { return Theme.vermillionDark }
        return Theme.ink
    }

    private func background(for choice: Vocab) -> Color {
        guard answered else { return Theme.card }
        if isRight(choice) { return Theme.leaf.opacity(0.14) }
        if isChosen(choice) { return Theme.vermillion.opacity(0.10) }
        return Theme.card
    }

    private func border(for choice: Vocab) -> Color {
        guard answered else { return Theme.hairlineStrong }
        if isRight(choice) { return Theme.leaf }
        if isChosen(choice) { return Theme.vermillion }
        return Theme.hairline
    }
}

/// Harter Print-Schatten nur für aktive Optionskarten (nicht für verblasste).
private struct OptionShadow: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        if active { content.hardShadow() } else { content }
    }
}
