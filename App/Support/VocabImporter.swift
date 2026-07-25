import Foundation
import SwiftData

/// Zentrale Import-Logik: fügt geparste Zeilen in eine (bei Bedarf neu angelegte)
/// Gruppe ein und überspringt Dubletten. Wird von den mitgelieferten Wortpaketen und
/// vom manuellen Import-Sheet genutzt.
enum VocabImporter {

    /// Ergebnis eines Imports: wie viele Vokabeln neu hinzugefügt, aktualisiert bzw. als
    /// unveränderte Dublette übersprungen wurden.
    struct Result {
        var added: Int
        var updated: Int
        var skipped: Int

        static func + (lhs: Result, rhs: Result) -> Result {
            Result(added: lhs.added + rhs.added,
                   updated: lhs.updated + rhs.updated,
                   skipped: lhs.skipped + rhs.skipped)
        }

        /// Übernimmt Bedeutung/Beispiel/TOPIK einer Zeile in eine bestehende Vokabel und
        /// zählt das Ergebnis (`updated`, falls sich etwas geändert hat, sonst `skipped`).
        /// Ein Beispiel oder TOPIK-Level wird nur gesetzt, wenn die Zeile es liefert – ein
        /// leeres Feld löscht also keine bereits gepflegten Werte.
        mutating func applyUpdate(from row: VocabCSV.Row, to vocab: Vocab) {
            var changed = false
            if vocab.meaning != row.meaning {
                vocab.meaning = row.meaning
                changed = true
            }
            if let example = row.example, vocab.example != example {
                vocab.example = example
                changed = true
            }
            if let topik = row.topik, vocab.topikLevel != topik {
                vocab.topikLevel = topik
                changed = true
            }
            if changed { updated += 1 } else { skipped += 1 }
        }
    }

    /// Importiert `rows` in die Gruppe mit dem Namen `name` (case-insensitiv gesucht in
    /// `existingGroups`, sonst neu angelegt). Der Abgleich erfolgt über das normalisierte
    /// koreanische Wort (Leerraum getrimmt, Groß-/Kleinschreibung egal):
    /// - neues Wort → anlegen (`added`),
    /// - vorhandenes Wort → Bedeutung/Beispiel/TOPIK aus der Zeile **aktualisieren**
    ///   (`updated`), sofern sich etwas ändert – der Lernfortschritt (Status, Zähler,
    ///   Fälligkeit …) bleibt dabei unberührt,
    /// - vorhandenes Wort ohne Änderung → `skipped`.
    /// Speichert **nicht**; das übernimmt der Aufrufer (z.B. einmal nach mehreren Paketen).
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
            // Live-Zählung (inkl. noch nicht gespeicherter Inserts), damit beim
            // "Alle importieren" jede neu angelegte Gruppe eine eigene, aufsteigende
            // Reihenfolge bekommt – `existingGroups` ist während der Schleife statisch.
            let order = (try? context.fetchCount(FetchDescriptor<VocabGroup>())) ?? existingGroups.count
            let newGroup = VocabGroup(name: trimmedName,
                                      colorHex: GroupPalette.random,
                                      sortOrder: order)
            context.insert(newGroup)
            group = newGroup
        }

        // Bereits vorhandene Wörter der Zielgruppe nach normalisiertem Wort indizieren,
        // damit sich eine Zeile gezielt einer bestehenden Vokabel zuordnen lässt. Neu
        // angelegte Wörter werden während der Schleife nachgetragen, damit auch eine
        // Dublette innerhalb desselben Imports greift.
        var byWord = Dictionary(group.vocabs.map { (normalize($0.word), $0) },
                                uniquingKeysWith: { first, _ in first })
        var result = Result(added: 0, updated: 0, skipped: 0)

        for row in rows {
            let key = normalize(row.word)
            if let existing = byWord[key] {
                result.applyUpdate(from: row, to: existing)
            } else {
                let vocab = Vocab(word: row.word, meaning: row.meaning, example: row.example,
                                  topik: row.topik, group: group)
                context.insert(vocab)
                byWord[key] = vocab
                result.added += 1
            }
        }
        return result
    }

    /// Normalisiert ein Wort für den Dubletten-Vergleich.
    private static func normalize(_ word: String) -> String {
        word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
