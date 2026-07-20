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

    /// Zerlegt eingefügten Text in Zeilen. Leere Zeilen, Zeilen ohne Bedeutung und
    /// eine evtl. vorhandene Kopfzeile (`word;meaning;…`, z.B. aus dem Export) werden
    /// übersprungen. Erkennt das Trennzeichen pro Zeile automatisch und respektiert
    /// per `"…"` gequotete Felder (inkl. `""`-Escaping), sodass ein Export wieder
    /// eingelesen werden kann. (Feldinterne Zeilenumbrüche werden nicht unterstützt.)
    static func parse(_ text: String) -> [Row] {
        text.split(whereSeparator: \.isNewline).compactMap { line -> Row? in
            let raw = String(line).trimmingCharacters(in: .whitespaces)
            guard !raw.isEmpty else { return nil }

            let fields = splitFields(raw, delimiter: delimiter(for: raw))
                .map { $0.trimmingCharacters(in: .whitespaces) }

            guard fields.count >= 2 else { return nil }
            let word = fields[0]
            let meaning = fields[1]
            guard !word.isEmpty, !meaning.isEmpty else { return nil }
            // Kopfzeile des Exports überspringen (nicht als Vokabel importieren).
            guard !(word.lowercased() == "word" && meaning.lowercased() == "meaning") else { return nil }
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

    /// Zerlegt eine Zeile am Trennzeichen, respektiert dabei `"…"`-gequotete Felder
    /// (Trennzeichen innerhalb der Quotes zählt nicht) und löst `""` zu `"` auf –
    /// die Umkehrung von `escape`.
    private static func splitFields(_ line: String, delimiter: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        let chars = Array(line)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" {
                        current.append("\"") // escaptes Quote
                        i += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    current.append(c)
                }
            } else if c == "\"" {
                inQuotes = true
            } else if c == delimiter {
                fields.append(current)
                current = ""
            } else {
                current.append(c)
            }
            i += 1
        }
        fields.append(current)
        return fields
    }

    /// Feld für CSV-Export absichern: bei Sonderzeichen in Anführungszeichen setzen.
    private static func escape(_ field: String) -> String {
        guard field.contains(";") || field.contains("\"") || field.contains("\n") else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
