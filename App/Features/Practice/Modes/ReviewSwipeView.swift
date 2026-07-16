import SwiftUI

/// Modus 2: Durchgehen. „Weiß ich" (links/Button) oder „Weiß ich nicht"
/// (rechts/Button → Bedeutung wird eingeblendet).
struct ReviewSwipeView: View {
    let item: PracticeItem
    let onAnswer: (Bool) -> Void

    @State private var revealed = false
    @State private var offset: CGSize = .zero

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            card
                .offset(x: offset.width)
                .rotationEffect(.degrees(Double(offset.width) / 20))
                .gesture(dragGesture)

            Text(L("practice.swipeHint"))
                .font(.appCaption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if revealed {
                Button {
                    onAnswer(false)
                } label: {
                    Label(L("common.next"), systemImage: "arrow.right")
                }
                .buttonStyle(.primary)
            } else {
                HStack(spacing: Theme.Spacing.s + 4) {
                    Button { handleDontKnow() } label: {
                        Label(L("practice.iDontKnow"), systemImage: "xmark")
                    }
                    .buttonStyle(.secondary(tint: .red))

                    Button { onAnswer(true) } label: {
                        Label(L("practice.iKnow"), systemImage: "checkmark")
                    }
                    .buttonStyle(.primary)
                }
            }
        }
    }

    private var card: some View {
        VStack(spacing: Theme.Spacing.m) {
            Text(item.prompt())
                .font(.appDisplay(44))
                .multilineTextAlignment(.center)
            if revealed {
                Divider().overlay(.white.opacity(0.4))
                Text(item.answer())
                    .font(.appTitle2)
                    .opacity(0.95)
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
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { if !revealed { offset = $0.translation } }
            .onEnded { value in
                // Nach dem Aufdecken nicht mehr wischen – die Antwort wurde bereits
                // als „nicht gewusst“ verbucht; ein Links-Wisch dürfte sie sonst
                // fälschlich als „gewusst“ markieren.
                guard !revealed else { return }
                if value.translation.width < -80 {
                    onAnswer(true)                 // nach links = weiß ich
                } else if value.translation.width > 80 {
                    withAnimation { offset = .zero; handleDontKnow() }
                } else {
                    withAnimation { offset = .zero }
                }
            }
    }

    private func handleDontKnow() {
        withAnimation { revealed = true }
    }
}
