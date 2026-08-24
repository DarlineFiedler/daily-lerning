import SwiftUI

/// Schreibgeschützte Detailansicht einer Vokabel – zum reinen Anschauen (z. B. aus der
/// Suche heraus), ohne das Bearbeiten-Formular zu öffnen. Über den „Bearbeiten"-Button
/// (`onEdit`) springt man von hier in den Editor. Rein lesend, kein `modelContext`-Zugriff.
struct VocabDetailView: View {
    let vocab: Vocab
    /// Wird ausgelöst, wenn der Nutzer von hier ins Bearbeiten-Formular wechseln will.
    let onEdit: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.m) {
                    header
                    if let example = vocab.example, !example.isEmpty {
                        infoCard(L("vocab.example")) {
                            Text(example)
                                .font(.appBody)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    infoCard(L("vocab.status")) {
                        StatusBadge(status: vocab.status)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let group = vocab.group {
                        infoCard(L("vocab.group")) {
                            HStack(spacing: Theme.Spacing.s) {
                                GroupColorDot(colorHex: group.colorHex)
                                Text(group.name).font(.appBody)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    if vocab.topikLevel != nil {
                        infoCard(L("topik.level")) {
                            TopikBadge(level: vocab.topikLevel)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(Theme.Spacing.m)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(L("vocab.details"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.close")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("common.edit")) {
                        onEdit()
                        dismiss()
                    }
                }
            }
        }
    }

    /// Kopf-Karte im Marken-Verlauf: großes Wort + Aussprache, darunter die Bedeutung.
    /// Optik bewusst identisch zur Übungskarte (`ReviewSwipeView.card`).
    private var header: some View {
        VStack(spacing: Theme.Spacing.m) {
            if let emoji = vocab.emoji, !emoji.isEmpty {
                Text(emoji)
                    .font(.system(size: 48))
                    .accessibilityHidden(true)
            }
            HStack(spacing: Theme.Spacing.s) {
                Text(vocab.word)
                    .font(.appDisplay(44))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                SpeakButton(text: vocab.word, font: .appTitle2, tint: .white)
            }
            Text(vocab.meaning)
                .font(.appTitle2)
                .opacity(0.95)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl + 16)
        .padding(.horizontal, Theme.Spacing.m)
        .background(Theme.brandGradientSoft, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .foregroundStyle(.white)
        .shadow(color: Theme.brandStart.opacity(0.3), radius: 16, y: 8)
    }

    /// Eine beschriftete Info-Karte: kleines Label über dem Inhalt.
    @ViewBuilder
    private func infoCard(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.appCaption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

#Preview {
    VocabDetailView(vocab: Vocab(word: "사랑", meaning: "Liebe"), onEdit: {})
}
