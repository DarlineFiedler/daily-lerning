import SwiftUI

/// Führt durch einen Lernvorgang und zeigt je Wort die passende Modus-View.
struct PracticeContainerView: View {
    @State var session: PracticeSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            if let item = session.currentItem {
                progressHeader
                ScrollView {
                    modeView(for: item)
                        .padding()
                        .id(session.index)   // erzwingt frische State pro Wort
                }
            } else {
                PracticeSummaryView(
                    correct: session.correctCount,
                    wrong: session.wrongCount,
                    onRestart: { withAnimation { session.restart() } },
                    onClose: { dismiss() }
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L("common.close")) { dismiss() }
            }
        }
    }

    private var progressHeader: some View {
        VStack(spacing: 6) {
            HStack {
                Text("\(session.position) / \(session.total)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Label("\(session.correctCount)", systemImage: "checkmark")
                    .foregroundStyle(.green)
                Label("\(session.wrongCount)", systemImage: "xmark")
                    .foregroundStyle(.red)
            }
            .font(.caption)
            ProgressView(value: Double(session.index), total: Double(max(session.total, 1)))
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func modeView(for item: PracticeItem) -> some View {
        let onAnswer: (Bool) -> Void = { correct in
            withAnimation { session.submit(correct: correct) }
        }
        switch item.mode {
        case .multipleChoice:
            MultipleChoiceView(item: item, onAnswer: onAnswer)
        case .review:
            ReviewSwipeView(item: item, onAnswer: onAnswer)
        case .writing:
            WritingView(item: item, onAnswer: onAnswer)
        }
    }
}

/// Zusammenfassung am Ende eines Lernvorgangs.
struct PracticeSummaryView: View {
    let correct: Int
    let wrong: Int
    let onRestart: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "party.popper.fill")
                .font(.system(size: 60))
                .foregroundStyle(.yellow)
            Text(L("practice.finished"))
                .font(.largeTitle.bold())
            Text(L("practice.finishedSummary", correct, wrong))
                .font(.title3)
                .foregroundStyle(.secondary)
            Spacer()
            VStack(spacing: 12) {
                Button(action: onRestart) {
                    Label(L("practice.restart"), systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                Button(action: onClose) {
                    Text(L("common.done")).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

/// Große Karte für das abgefragte Wort.
struct PromptCard: View {
    let text: String
    var subtitle: String?

    var body: some View {
        VStack(spacing: 8) {
            Text(text)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            if let subtitle {
                Text(subtitle)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 20))
    }
}
