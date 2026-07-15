import SwiftUI
import SwiftData

/// Zeile einer Vokabel in Listen. Tippen wählt die Vokabel aus (`onSelect`),
/// das Widget-Symbol schaltet die Anzeige auf dem Lock Screen an/aus.
struct VocabRow: View {
    @Bindable var vocab: Vocab
    var showGroup: Bool = false
    var onSelect: () -> Void = {}

    @Environment(\.modelContext) private var context

    var body: some View {
        HStack(spacing: 12) {
            StatusDot(status: vocab.status)

            VStack(alignment: .leading, spacing: 2) {
                Text(vocab.word)
                    .font(.headline)
                Text(vocab.meaning)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if showGroup, let group = vocab.group {
                    HStack(spacing: 4) {
                        GroupColorDot(colorHex: group.colorHex, size: 8)
                        Text(group.name)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)

            Button(action: toggleWidget) {
                Image(systemName: "lock.iphone")
                    .foregroundStyle(vocab.includeInWidget ? Color.accentColor : Color.secondary.opacity(0.35))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(L("vocab.widgetToggle"))
        }
        .padding(.vertical, 2)
    }

    private func toggleWidget() {
        vocab.includeInWidget.toggle()
        try? context.save()
        WidgetSnapshotWriter.refresh(context: context)
    }
}
