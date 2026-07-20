import SwiftData
import SwiftUI

/// Wird beim Antippen des Lock-Screen-Widgets geöffnet (Deep-Link) und zeigt das
/// Wort mit Bedeutung. Auch als generische „Karte“ nutzbar.
struct WordRevealSheet: View {
    let wordID: UUID
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var vocab: Vocab?

    var body: some View {
        NavigationStack {
            Group {
                if let vocab {
                    VStack(spacing: 20) {
                        if let group = vocab.group {
                            Label(group.name, systemImage: "rectangle.stack.fill")
                                .font(.appSubheadline.weight(.semibold))
                                .foregroundStyle(Color(hex: group.colorHex))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(hex: group.colorHex).opacity(0.14), in: Capsule())
                        }
                        HStack(spacing: Theme.Spacing.s) {
                            Text(vocab.word)
                                .font(.appDisplay(56))
                                .multilineTextAlignment(.center)
                            SpeakButton(text: vocab.word, font: .appTitle)
                        }
                        Text(vocab.meaning)
                            .font(.appTitle2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        if let example = vocab.example, !example.isEmpty {
                            Text(example)
                                .font(.appBody)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                                .padding(.top, 4)
                        }
                        StatusBadge(status: vocab.status)
                            .padding(.top, 8)
                    }
                    .padding(Theme.Spacing.l)
                } else {
                    ContentUnavailableView(L("widget.empty"), systemImage: "questionmark.circle")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(background)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("common.done")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear(perform: fetch)
    }

    /// Dezenter, nach unten ausblendender Verlauf in der Gruppenfarbe.
    @ViewBuilder
    private var background: some View {
        let base = vocab?.group.map { Color(hex: $0.colorHex) } ?? Theme.brandStart
        LinearGradient(
            colors: [base.opacity(0.16), Theme.background],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private func fetch() {
        let id = wordID
        let descriptor = FetchDescriptor<Vocab>(predicate: #Predicate { $0.id == id })
        vocab = try? context.fetch(descriptor).first
    }
}
