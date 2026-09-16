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
                    statusCard
                    widgetCard
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
                    .font(.appDisplay(44))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                SpeakButton(text: vocab.word, font: .appTitle2, tint: Theme.vermillion)
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

    /// Status als Schnellwechsel: tippbares Menü, das den Lernstatus direkt setzt
    /// (inkl. Zähler/Wiederholungsplan via `setStatusManually`) – ohne den Editor.
    private var statusCard: some View {
        infoCard(L("vocab.status")) {
            Menu {
                ForEach(LearningStatus.allCases) { status in
                    Button { apply(status) } label: {
                        Label(L(status.titleKey), systemImage: status.systemImage)
                    }
                }
            } label: {
                HStack(spacing: Theme.Spacing.s) {
                    StatusBadge(status: vocab.status)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.appCaption)
                        .foregroundStyle(Theme.inkMuted)
                    Spacer()
                }
            }
            .accessibilityLabel(L("vocab.changeStatus"))
        }
    }

    /// Sperrbildschirm-Schalter (`includeInWidget`) direkt in der Detailansicht. Schreibt
    /// beim Umschalten und frischt Snapshot/Badge auf, damit das Widget sofort passt.
    private var widgetCard: some View {
        Toggle(isOn: $vocab.includeInWidget) {
            Label(L("vocab.widgetToggle"), systemImage: "lock.iphone")
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
        .modelContainer(PersistenceController.preview)
}
