import Foundation
import SwiftData

/// Eine frei benennbare, farbcodierte Vokabelgruppe (z.B. „Verben“, „Essen“).
@Model
final class VocabGroup {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "#3B82F6"
    var sortOrder: Int = 0
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \Vocab.group)
    var vocabs: [Vocab] = []

    init(name: String, colorHex: String = GroupPalette.random, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.createdAt = .now
    }

    // MARK: - Abgeleitete Werte

    var vocabCount: Int { vocabs.count }

    func count(of status: LearningStatus) -> Int {
        vocabs.filter { $0.status == status }.count
    }
}
