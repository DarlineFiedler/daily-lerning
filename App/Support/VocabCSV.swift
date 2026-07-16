import Foundation

/// Import/Export von Vokabeln als einfaches Zeilenformat.
/// Eine Zeile = eine Vokabel; Felder getrennt durch `;`, Tab oder `,` (in dieser
/// Priorität automatisch erkannt). Reihenfolge: Wort, Bedeutung, Beispiel (optional).
enum VocabCSV {

    struct Row: Equatable {
        let word: String
        let meaning: String
        let example: String?
    }

    /// Zerlegt eingefügten Text in Zeilen. Leere Zeilen und Zeilen ohne Bedeutung
    /// werden übersprungen. Erkennt das Trennzeichen pro Zeile automatisch.
    static func parse(_ text: String) -> [Row] {
        text.split(whereSeparator: \.isNewline).compactMap { line -> Row? in
            let raw = String(line).trimmingCharacters(in: .whitespaces)
            guard !raw.isEmpty else { return nil }

            let fields = raw.split(separator: delimiter(for: raw), omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }

            guard fields.count >= 2 else { return nil }
            let word = fields[0]
            let meaning = fields[1]
            guard !word.isEmpty, !meaning.isEmpty else { return nil }
            let example = fields.count >= 3 && !fields[2].isEmpty ? fields[2] : nil
            return Row(word: word, meaning: meaning, example: example)
        }
    }

    /// Serialisiert Vokabeln als CSV (Semikolon-getrennt), inkl. Header.
    static func export(_ vocabs: [Vocab]) -> String {
        var lines = ["word;meaning;example;group;status"]
        for v in vocabs {
            let fields = [
                v.word,
                v.meaning,
                v.example ?? "",
                v.group?.name ?? "",
                L(v.status.titleKey)
            ].map(escape)
            lines.append(fields.joined(separator: ";"))
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Intern

    /// Wählt das Trennzeichen: Semikolon, dann Tab, dann Komma.
    private static func delimiter(for line: String) -> Character {
        if line.contains(";") { return ";" }
        if line.contains("\t") { return "\t" }
        return ","
    }

    /// Feld für CSV-Export absichern: bei Sonderzeichen in Anführungszeichen setzen.
    private static func escape(_ field: String) -> String {
        guard field.contains(";") || field.contains("\"") || field.contains("\n") else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
