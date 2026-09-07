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
                            Text(example).font(.appBody)
                        }
                    }
                    infoCard(L("vocab.status")) {
                        StatusBadge(status: vocab.status)
                    }
                    if vocab.hasBeenPracticed { accuracyCard }
                    if let group = vocab.group {
                        infoCard(L("vocab.group")) {
                            HStack(spacing: Theme.Spacing.s) {
                                GroupColorDot(colorHex: group.colorHex)
                                Text(group.name).font(.appBody)
                            }
                        }
                    }
                    if vocab.topikLevel != nil {
                        infoCard(L("topik.level")) {
                            TopikBadge(level: vocab.topikLevel)
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
                    // Kein `dismiss()` hier: Der Aufrufer schaltet dasselbe Sheet vom Ansehen-
                    // auf den Editier-Fall um (ein Presentation-Controller). Ein zusätzliches
                    // Schließen würde das Sheet zumachen, bevor der Editor erscheinen kann.
                    Button(L("common.edit"), action: onEdit)
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
        .heroCardStyle()
        .accessibilityElement(children: .combine)
    }

    /// Trefferquote über die Lebenszeit: richtige Antworten / Versuche. Bei Problemwörtern
    /// (siehe [[Vocab]] `isProblemWord`) zusätzlich ein Warnhinweis.
    private var accuracyCard: some View {
        let attempts = vocab.timesPracticed
        let correct = max(0, attempts - vocab.totalWrongCount)
        let percent = attempts == 0 ? 0 : Int(round(Double(correct) / Double(attempts) * 100))
        return infoCard(L("vocab.accuracy")) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L("vocab.accuracyDetail", percent, attempts))
                    .font(.appBody)
                    .monospacedDigit()
                if vocab.isProblemWord {
                    Label(L("vocab.problemWord"), systemImage: "exclamationmark.triangle.fill")
                        .font(.appSubheadline)
                        .foregroundStyle(Theme.wrong)
                }
            }
        }
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
