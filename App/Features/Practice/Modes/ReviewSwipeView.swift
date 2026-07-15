import SwiftUI

/// Modus 2: Durchgehen. „Weiß ich“ (links/Button) oder „Weiß ich nicht“
/// (rechts/Button → Bedeutung wird eingeblendet).
struct ReviewSwipeView: View {
    let item: PracticeItem
    let onAnswer: (Bool) -> Void

    @State private var revealed = false
    @State private var offset: CGSize = .zero

    var body: some View {
        VStack(spacing: 24) {
            card
                .offset(x: offset.width)
                .rotationEffect(.degrees(Double(offset.width) / 20))
                .gesture(dragGesture)

            Text(L("practice.swipeHint"))
                .font(.caption)
                .foregroundStyle(.secondary)

            if revealed {
                Button {
                    onAnswer(false)
                } label: {
                    Label(L("common.next"), systemImage: "arrow.right")
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
            } else {
                HStack(spacing: 12) {
                    Button { handleDontKnow() } label: {
                        Label(L("practice.iDontKnow"), systemImage: "xmark")
                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)

                    Button { onAnswer(true) } label: {
                        Label(L("practice.iKnow"), systemImage: "checkmark")
                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
            }
        }
    }

    private var card: some View {
        VStack(spacing: 12) {
            Text(item.prompt())
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            if revealed {
                Divider()
                Text(item.answer())
                    .font(.title2)
                    .foregroundStyle(.secondary)
                if let example = item.vocab.example, !example.isEmpty {
                    Text(example)
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal)
        .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 20))
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { offset = $0.translation }
            .onEnded { value in
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
