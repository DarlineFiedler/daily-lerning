import Foundation
import SwiftData

/// Zentrale Import-Logik: fügt geparste Zeilen in eine (bei Bedarf neu angelegte)
/// Gruppe ein und überspringt Dubletten. Wird von den mitgelieferten Wortpaketen und
/// vom manuellen Import-Sheet genutzt.
enum VocabImporter {

    /// Ergebnis eines Imports: wie viele Vokabeln neu hinzugefügt bzw. als Dublette
    /// übersprungen wurden.
    struct Result {
        var added: Int
        var skipped: Int

        static func + (lhs: Result, rhs: Result) -> Result {
            Result(added: lhs.added + rhs.added, skipped: lhs.skipped + rhs.skipped)
        }
    }

    /// Importiert `rows` in die Gruppe mit dem Namen `name` (case-insensitiv gesucht in
    /// `existingGroups`, sonst neu angelegt). Bereits vorhandene Wörter der Zielgruppe –
    /// gleiches koreanisches Wort, normalisiert (Leerraum getrimmt, Groß-/Kleinschreibung
    /// egal) – werden übersprungen. Speichert **nicht**; das übernimmt der Aufrufer
    /// (z.B. einmal nach mehreren Paketen).
    @discardableResult
    static func importRows(_ rows: [VocabCSV.Row],
                           intoGroupNamed name: String,
                           context: ModelContext,
                           existingGroups: [VocabGroup]) -> Result {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        let group: VocabGroup
        if let match = existingGroups.first(where: {
            $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame
        }) {
            group = match
        } else {
            let newGroup = VocabGroup(name: trimmedName,
                                      colorHex: GroupPalette.random,
                                      sortOrder: existingGroups.count)
            context.insert(newGroup)
            group = newGroup
        }

        var existingWords = Set(group.vocabs.map { normalize($0.word) })
        var result = Result(added: 0, skipped: 0)

        for row in rows {
            let key = normalize(row.word)
            if existingWords.contains(key) {
                result.skipped += 1
                continue
            }
            context.insert(Vocab(word: row.word, meaning: row.meaning, example: row.example, group: group))
            existingWords.insert(key)
            result.added += 1
        }
        return result
    }

    /// Normalisiert ein Wort für den Dubletten-Vergleich.
    private static func normalize(_ word: String) -> String {
        word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
