import SwiftUI
import SwiftData

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
                            Label(group.name, systemImage: "rectangle.stack")
                                .font(.subheadline)
                                .foregroundStyle(Color(hex: group.colorHex))
                        }
                        Text(vocab.word)
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                        Text(vocab.meaning)
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        if let example = vocab.example, !example.isEmpty {
                            Text(example)
                                .font(.callout)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                                .padding(.top, 4)
                        }
                        StatusBadge(status: vocab.status)
                            .padding(.top, 8)
                    }
                    .padding()
                } else {
                    ContentUnavailableView(L("widget.empty"), systemImage: "questionmark.circle")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("common.done")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear(perform: fetch)
    }

    private func fetch() {
        let id = wordID
        let descriptor = FetchDescriptor<Vocab>(predicate: #Predicate { $0.id == id })
        vocab = try? context.fetch(descriptor).first
    }
}
