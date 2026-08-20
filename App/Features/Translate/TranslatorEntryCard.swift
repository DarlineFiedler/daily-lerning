import SwiftUI

/// Einstiegskarte in den Übersetzer (DeepL-artig): Wörter/Sätze übersetzen und anhören.
/// Wird auf dem Home-Screen angezeigt und öffnet die [[TranslatorView]] als Sheet.
struct TranslatorEntryCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: "character.bubble.fill")
                    .font(.appTitle2)
                    .foregroundStyle(Theme.brandStart)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("home.translator.title"))
                        .font(.appHeadline)
                        .foregroundStyle(.primary)
                    Text(L("home.translator.subtitle"))
                        .font(.appSubheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.appHeadline)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(padding: Theme.Spacing.l)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}
