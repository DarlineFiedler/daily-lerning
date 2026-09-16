import SwiftUI

/// Detailansicht einer Vokabel – zum Anschauen (z. B. aus der Suche heraus). Bewusst
/// schlank: Direkt änderbar sind hier nur **Status** (Schnellwechsel) und der
/// **Sperrbildschirm-Schalter** (`includeInWidget`); alles andere läuft weiter über den
/// „Bearbeiten"-Button (`onEdit`) im Editor.
struct VocabDetailView: View {
    @Bindable var vocab: Vocab
    /// Wird ausgelöst, wenn der Nutzer von hier ins Bearbeiten-Formular wechseln will.
    let onEdit: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.m) {
                    header
                    if let example = vocab.example, !example.isEmpty {
                        exampleCard(example)
                    }
                    statusCard
                    if vocab.hasBeenPracticed { accuracyCard }
                    widgetCard
                    deleteButton
                }
                .padding(Theme.Spacing.m)
            }
            .paperBackground()
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
                    .font(.appDisplay(46))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                SpeakButton(text: vocab.word, font: .appTitle2, tint: Theme.vermillion)
            }
            Text(vocab.meaning)
                .font(.appTitle2)
                .foregroundStyle(Theme.ink.opacity(0.65))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity)
        // Beet-Name oben links, TOPIK-Badge oben rechts (Design-Handoff 2j).
        .overlay(alignment: .topLeading) {
            if let group = vocab.group {
                SectionLabel(group.name)
            }
        }
        .overlay(alignment: .topTrailing) {
            if vocab.topikLevel != nil {
                TopikBadge(level: vocab.topikLevel)
            }
        }
        .heroCardStyle()
        .accessibilityElement(children: .combine)
    }

    /// Beispielsatz-Karte mit grünem Akzentstreifen (Design-Handoff 2j).
    private func exampleCard(_ example: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionLabel(L("vocab.example"))
            Text(example)
                .font(.appDisplay(19, weight: .regular))
                .foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .groupAccent(Theme.leaf)
    }

    /// „Wort löschen" – zerstörerische Aktion, zinnoberrot am unteren Rand.
    private var deleteButton: some View {
        Button(role: .destructive) { showDeleteConfirm = true } label: {
            Text(L("vocab.delete"))
                .font(.appCaption)
                .textCase(.uppercase)
                .foregroundStyle(Theme.vermillion)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.s)
        }
        .buttonStyle(.plain)
        .confirmationDialog(L("vocab.deleteConfirm"), isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button(L("common.delete"), role: .destructive) { deleteVocab() }
            Button(L("common.cancel"), role: .cancel) {}
        }
    }

    private func deleteVocab() {
        context.delete(vocab)
        context.saveOrLog()
        AppContentRefresh.afterVocabChange(context: context)
        dismiss()
    }

    /// Status als Schnellwechsel: tippbares Menü, das den Lernstatus direkt setzt
    /// (inkl. Zähler/Wiederholungsplan via `setStatusManually`) – ohne den Editor.
    private var statusCard: some View {
        infoCard(L("vocab.setStatus")) {
            PaperSegmented(
                options: LearningStatus.allCases,
                title: { $0.gardenStageEmoji },
                selection: Binding(get: { vocab.status }, set: { apply($0) }),
                selectedFill: Theme.ocher
            )
            .accessibilityLabel(L("vocab.changeStatus"))
        }
    }

    /// Sperrbildschirm-Schalter (`includeInWidget`) direkt in der Detailansicht. Schreibt
    /// beim Umschalten und frischt Snapshot/Badge auf, damit das Widget sofort passt.
    private var widgetCard: some View {
        Toggle(isOn: $vocab.includeInWidget) {
            Text(L("vocab.widgetToggle"))
                .font(.appBody)
                .foregroundStyle(Theme.ink)
        }
        .tint(Theme.leaf)
        .onChange(of: vocab.includeInWidget) { persist() }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    /// Setzt den Lernstatus manuell und speichert/aktualisiert.
    private func apply(_ status: LearningStatus) {
        vocab.setStatusManually(status)
        persist()
    }

    /// Speichert die Änderung und frischt Widget-Snapshot + App-Icon-Badge auf.
    private func persist() {
        context.saveOrLog()
        AppContentRefresh.afterVocabChange(context: context)
    }

    /// Trefferquote über die Lebenszeit: richtige Antworten / Versuche. Bei Problemwörtern
    /// (siehe [[Vocab]] `isProblemWord`) zusätzlich ein Warnhinweis.
    private var accuracyCard: some View {
        infoCard(L("vocab.accuracy")) {
            VStack(spacing: Theme.Spacing.s) {
                statRow(L("vocab.stat.practiced"), value: "\(vocab.timesPracticed)×")
                statRow(L("vocab.stat.wrong"), value: "\(vocab.totalWrongCount)×",
                        valueColor: vocab.totalWrongCount > 0 ? Theme.vermillion : Theme.ink)
                statRow(L("vocab.stat.streak"), value: "\(vocab.successCounter)")
                if vocab.isProblemWord {
                    Label(L("vocab.problemWord"), systemImage: "exclamationmark.triangle.fill")
                        .font(.appSubheadline)
                        .foregroundStyle(Theme.wrong)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    /// Eine Kennzahl-Zeile: serifer Titel links, Mono-Wert rechts (Design-Handoff 2j).
    private func statRow(_ label: String, value: String, valueColor: Color = Theme.ink) -> some View {
        HStack {
            Text(label)
                .font(.appSubheadline)
                .foregroundStyle(Theme.inkSecondary)
            Spacer()
            Text(value)
                .font(.appMono(13))
                .foregroundStyle(valueColor)
        }
    }

    /// Eine beschriftete Info-Karte: kleines Label über dem Inhalt.
    @ViewBuilder
    private func infoCard(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionLabel(title)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

#Preview {
    VocabDetailView(vocab: Vocab(word: "사랑", meaning: "Liebe"), onEdit: {})
        .modelContainer(PersistenceController.preview)
}
