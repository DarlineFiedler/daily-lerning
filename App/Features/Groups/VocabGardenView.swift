import SwiftUI

/// Spielerische „Garten"-Ansicht einer Gruppe (Issue #92): jedes Wort ist eine Pflanze,
/// deren Wachstumsstufe direkt am Lernstatus hängt (Samen → Sprössling → Grün → Blüte).
/// Additiv zur Statusverteilung und in [[GroupDetailView]] umschaltbar. Rein aus
/// [[VocabGarden]] abgeleitet – keine eigene Datenquelle, aktualisiert sich dadurch
/// automatisch nach jeder Übungsrunde.
struct VocabGardenView: View {
    let vocabs: [Vocab]
    let colorHex: String

    private var garden: VocabGarden { VocabGarden(vocabs: vocabs) }
    private var tint: Color { Color(hex: colorHex) }

    private let columns = [GridItem(.adaptive(minimum: 56), spacing: Theme.Spacing.s)]

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            if garden.isFullyBloomed { bloomBanner }
            if garden.showsSummary {
                summary
            } else {
                grid
            }
        }
    }

    /// Feier-Banner für den voll erblühten Garten (alle Wörter gelernt).
    private var bloomBanner: some View {
        HStack(spacing: Theme.Spacing.s) {
            Text("🌷🌸🌼").font(.appTitle3)
            Text(L("garden.fullyBloomed"))
                .font(.appSubheadline.weight(.semibold))
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(.white)
        .background(tint.vibrantGradient, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    /// Ein Beet aus Einzelpflanzen (`LazyVGrid`, damit auch mittelgroße Gruppen flüssig
    /// scrollen; ab `VocabGarden.tileLimit` greift stattdessen die Zusammenfassung).
    private var grid: some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.s) {
            ForEach(vocabs) { vocab in
                tile(vocab)
            }
        }
    }

    private func tile(_ vocab: Vocab) -> some View {
        let isBloomed = vocab.status == .learned
        let plant = VocabGarden.plantEmoji(for: vocab.status, groupHex: colorHex)
        return ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(isBloomed ? 0.22 : 0.08))
                .frame(width: 56, height: 56)
                .overlay(Text(plant).font(.system(size: 28)))
            // Wort-Emoji als kleine thematische Deko an der erblühten Pflanze.
            if isBloomed, let deco = vocab.emoji, !deco.isEmpty {
                Text(deco)
                    .font(.system(size: 15))
                    .padding(3)
                    .background(Theme.surface, in: Circle())
                    .offset(x: 4, y: 4)
            }
        }
        .frame(width: 60, height: 60)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(vocab.word) – \(L(vocab.status.titleKey))"))
    }

    /// Zusammenfassung für große Gruppen: Anzahl je Wachstumsstufe (blühend zuerst).
    private var summary: some View {
        VStack(spacing: Theme.Spacing.s) {
            ForEach(LearningStatus.allCases.reversed()) { status in
                let count = garden.count(of: status)
                if count > 0 {
                    HStack(spacing: Theme.Spacing.m) {
                        Text(VocabGarden.plantEmoji(for: status, groupHex: colorHex))
                            .font(.appTitle3)
                        Text(L(status.titleKey)).font(.appBody)
                        Spacer()
                        Text("\(count)")
                            .font(.appHeadline.weight(.semibold))
                            .foregroundStyle(tint)
                    }
                }
            }
        }
        .cardStyle()
    }
}
