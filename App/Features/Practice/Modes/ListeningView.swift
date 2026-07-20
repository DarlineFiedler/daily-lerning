import SwiftUI

/// Modus 4: Hör-Verständnis. Das koreanische Wort wird vorgelesen (offline via
/// `SpeechService`), die passende Bedeutung wird aus vier Optionen gewählt.
/// Die Richtung ist hier fest Wort→Bedeutung (siehe `PracticeSession.buildItems`).
struct ListeningView: View {
    let item: PracticeItem
    let onAnswer: (Bool) -> Void

    @State private var selected: Vocab?

    private var answered: Bool { selected != nil }
    private var isCorrect: Bool { selected?.id == item.vocab.id }

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            audioCard

            ChoiceOptionsView(item: item, selected: $selected)

            if answered {
                Button {
                    onAnswer(isCorrect)
                } label: {
                    Label(L("common.next"), systemImage: "arrow.right")
                }
                .buttonStyle(.primary)
            }
        }
        .onAppear { speak() }
    }

    /// Große Karte mit Lautsprecher – tippen spielt das Wort erneut ab.
    private var audioCard: some View {
        Button { speak() } label: {
            VStack(spacing: Theme.Spacing.s) {
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 52))
                Text(L("practice.listen.replay"))
                    .font(.appSubheadline.weight(.medium))
                    .opacity(0.9)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.xl + 8)
            .padding(.horizontal, Theme.Spacing.m)
            .background(Theme.brandGradientSoft, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .foregroundStyle(.white)
            .shadow(color: Theme.brandStart.opacity(0.3), radius: 16, y: 8)
        }
        .buttonStyle(.plain)
        // Nach dem Beantworten das Wort einblenden – dann verrät es nichts mehr.
        .overlay(alignment: .bottom) {
            if answered {
                Text(item.vocab.word)
                    .font(.appHeadline)
                    .foregroundStyle(.white)
                    .padding(.bottom, Theme.Spacing.m)
            }
        }
    }

    private func speak() {
        SpeechService.shared.speak(item.vocab.word)
    }
}
