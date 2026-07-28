import SwiftUI

/// Modus 6: Memory. Wort- und Bedeutungskarten liegen gemischt aus; zwei werden
/// aufgedeckt und müssen ein Paar (Wort ↔ eigene Bedeutung) bilden. Richtige Paare
/// bleiben offen, falsche drehen sich zurück. Große Sessions werden in Runden zu
/// höchstens `maxPairsPerRound` Paaren aufgeteilt.
///
/// Eigenständiges Kartenfeld statt Einzelkarten: das Board verbucht jedes Wort über
/// `session.record(result:for:)` (Paare werden in beliebiger Reihenfolge gelöst).
/// Wertung „erster Versuch entscheidet": ein Wort zählt als falsch, sobald eine
/// seiner Karten an einem Fehlversuch beteiligt war, bevor das Paar gefunden wurde.
struct MemoryBoardView: View {
    let session: PracticeSession

    private static let maxPairsPerRound = 8
    private static let flipBackDelay = Duration.milliseconds(700)

    @State private var roundStart = 0
    @State private var cards: [MemoryCard] = []
    @State private var firstUp: MemoryCard.ID?
    @State private var spoiled: Set<UUID> = []
    @State private var matchedInRound = 0
    @State private var busy = false

    /// Wörter der aktuellen Runde (Ausschnitt aus allen Session-Items).
    private var roundVocabs: [Vocab] {
        let items = session.items
        let end = min(roundStart + Self.maxPairsPerRound, items.count)
        guard roundStart < end else { return [] }
        return items[roundStart ..< end].map(\.vocab)
    }

    private var columns: [GridItem] {
        let count = min(4, max(2, Int(Double(cards.count).squareRoot().rounded(.up))))
        return Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.s), count: count)
    }

    var body: some View {
        VStack(spacing: 0) {
            PracticeProgressHeader(session: session)
            ScrollView {
                LazyVGrid(columns: columns, spacing: Theme.Spacing.s) {
                    ForEach(cards) { card in
                        MemoryCardView(card: card) { tap(card) }
                    }
                }
                .padding(Theme.Spacing.m)
            }
        }
        .onAppear { if cards.isEmpty { buildRound() } }
    }

    // MARK: - Rundenaufbau

    private func buildRound() {
        let faces: [MemoryCard] = roundVocabs.flatMap { vocab in
            [MemoryCard(vocab: vocab, face: .word), MemoryCard(vocab: vocab, face: .meaning)]
        }
        cards = faces.shuffled()
        firstUp = nil
        matchedInRound = 0
        busy = false
    }

    private func advanceRound() {
        roundStart += roundVocabs.count
        // Sind keine Wörter mehr übrig, ist die Session fertig (der Container zeigt dann
        // die Zusammenfassung) – kein neues Board mehr bauen.
        guard roundStart < session.items.count else { return }
        withAnimation { buildRound() }
    }

    // MARK: - Aufdeck-Logik

    private func tap(_ card: MemoryCard) {
        guard !busy, !card.isMatched, !card.isFaceUp else { return }
        setFaceUp(card.id, true)

        guard let firstID = firstUp, let first = cards.first(where: { $0.id == firstID }) else {
            firstUp = card.id
            return
        }

        if first.vocab.id == card.vocab.id {
            resolveMatch(first, card)
        } else {
            resolveMismatch(first, card)
        }
    }

    private func resolveMatch(_ a: MemoryCard, _ b: MemoryCard) {
        setMatched(a.id)
        setMatched(b.id)
        firstUp = nil
        matchedInRound += 1
        // „Erster Versuch": falsch, wenn eine der Karten schon an einem Fehler beteiligt war.
        session.record(result: !spoiled.contains(a.vocab.id), for: a.vocab)
        if matchedInRound == roundVocabs.count { advanceRound() }
    }

    private func resolveMismatch(_ a: MemoryCard, _ b: MemoryCard) {
        spoiled.insert(a.vocab.id)
        spoiled.insert(b.vocab.id)
        busy = true
        firstUp = nil
        Task {
            try? await Task.sleep(for: Self.flipBackDelay)
            withAnimation {
                setFaceUp(a.id, false)
                setFaceUp(b.id, false)
            }
            busy = false
        }
    }

    // MARK: - Karten-Mutation

    private func setFaceUp(_ id: MemoryCard.ID, _ up: Bool) {
        guard let i = cards.firstIndex(where: { $0.id == id }) else { return }
        cards[i].isFaceUp = up
    }

    private func setMatched(_ id: MemoryCard.ID) {
        guard let i = cards.firstIndex(where: { $0.id == id }) else { return }
        cards[i].isMatched = true
        cards[i].isFaceUp = true
    }
}

/// Eine Memory-Karte: entweder die Wort- oder die Bedeutungsseite eines Vokabels.
struct MemoryCard: Identifiable {
    enum Face { case word, meaning }

    let id = UUID()
    let vocab: Vocab
    let face: Face
    var isMatched = false
    var isFaceUp = false

    var text: String { face == .word ? vocab.word : vocab.meaning }
}

/// Einzelne, antippbare Memory-Karte mit einfacher Flip-Darstellung.
private struct MemoryCardView: View {
    let card: MemoryCard
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if card.isFaceUp || card.isMatched {
                    Text(card.text)
                        .font(.appBody.weight(.semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.4)
                        .padding(6)
                } else {
                    Image(systemName: "questionmark")
                        .font(.appTitle2)
                        .foregroundStyle(Theme.brandStart)
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(background, in: RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .strokeBorder(card.isMatched ? LearningStatus.learned.color : .clear, lineWidth: 2)
            )
            .opacity(card.isMatched ? 0.6 : 1)
            .rotation3DEffect(.degrees(card.isFaceUp || card.isMatched ? 0 : 180), axis: (x: 0, y: 1, z: 0))
        }
        .buttonStyle(.plain)
        .disabled(card.isMatched)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: card.isFaceUp)
    }

    private var background: AnyShapeStyle {
        if card.isMatched { return AnyShapeStyle(LearningStatus.learned.color.opacity(0.9)) }
        if card.isFaceUp { return AnyShapeStyle(Theme.brandGradientSoft) }
        return AnyShapeStyle(Theme.surfaceMuted)
    }
}
