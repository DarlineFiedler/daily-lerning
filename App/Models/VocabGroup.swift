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
    /// Archivierte Gruppen bleiben mitsamt Vokabeln erhalten, werden aber aus den
    /// aktiven Flächen (Home, Übungsauswahl, Widget, App-Icon-Badge) ausgeblendet,
    /// bis sie reaktiviert werden. Additiv mit Default `false` → SwiftData-Lightweight-
    /// Migration, Bestandsdaten bekommen `false`.
    var isArchived: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \Vocab.group)
    var vocabs: [Vocab] = []

    init(name: String, colorHex: String = GroupPalette.random, sortOrder: Int = 0,
         isArchived: Bool = false) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.createdAt = .now
        self.isArchived = isArchived
    }

    // MARK: - Abgeleitete Werte

    var vocabCount: Int { vocabs.count }

    func count(of status: LearningStatus) -> Int {
        vocabs.filter { $0.status == status }.count
    }
}
