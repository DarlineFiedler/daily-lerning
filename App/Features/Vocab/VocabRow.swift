import SwiftData
import SwiftUI

/// Zeile einer Vokabel in Listen. Tippen wählt die Vokabel aus (`onSelect`),
/// das Widget-Symbol schaltet die Anzeige auf dem Lock Screen an/aus.
/// Im Auswahl-Modus (`isSelecting`) tippt die ganze Zeile die Markierung um.
struct VocabRow: View {
    @Bindable var vocab: Vocab
    var showGroup: Bool = false
    var isSelecting: Bool = false
    var isSelected: Bool = false
    var onSelect: () -> Void = {}

    @Environment(\.modelContext) private var context

    var body: some View {
        HStack(spacing: 12) {
            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.appTitle3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.4))
                    .accessibilityHidden(true)
            }

            StatusDot(status: vocab.status)

            if let emoji = vocab.emoji, !emoji.isEmpty {
                Text(emoji)
                    .font(.appTitle3)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(vocab.word)
                    .font(.appHeadline)
                Text(vocab.meaning)
                    .font(.appSubheadline)
                    .foregroundStyle(.secondary)
                if showGroup, let group = vocab.group {
                    HStack(spacing: 4) {
                        GroupColorDot(colorHex: group.colorHex, size: 8)
                        Text(group.name)
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !isSelecting {
                Button(action: toggleWidget) {
                    Image(systemName: "lock.iphone")
                        .font(.appHeadline)
                        .foregroundStyle(vocab.includeInWidget ? Color.accentColor : Color.secondary.opacity(0.35))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(L("vocab.widgetToggle"))
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        // Im Auswahl-Modus ist die ganze Zeile ein tippbares Auswahl-Element; sonst
        // bleiben Widget-Button & Co. eigenständig für VoiceOver erreichbar.
        .accessibilityElement(children: isSelecting ? .combine : .contain)
        .accessibilityAddTraits(isSelecting && isSelected ? .isSelected : [])
    }

    private func toggleWidget() {
        vocab.includeInWidget.toggle()
        context.saveOrLog()
        WidgetSnapshotWriter.refresh(context: context)
    }
}
