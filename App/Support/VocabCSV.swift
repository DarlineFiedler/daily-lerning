import Foundation

/// Import/Export von Vokabeln als einfaches Zeilenformat.
/// Eine Zeile = eine Vokabel; Felder getrennt durch `;`, Tab oder `,` (in dieser
/// Priorität automatisch erkannt). Reihenfolge: Wort, Bedeutung, Beispiel (optional),
/// TOPIK-Niveau (optional, 4. Spalte – siehe [[TopikLevel]] und Issue #38).
enum VocabCSV {

    struct Row: Equatable {
        let word: String
        let meaning: String
        let example: String?
        /// Optionale TOPIK-Einstufung aus der 4. Spalte. `nil`, wenn die Spalte fehlt
        /// oder einen unbekannten Wert enthält (Default für alle bisherigen Dateien).
        let topik: TopikLevel?

        init(word: String, meaning: String, example: String?, topik: TopikLevel? = nil) {
            self.word = word
            self.meaning = meaning
            self.example = example
            self.topik = topik
        }
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
            let topik = fields.count >= 4 ? TopikLevel(csv: fields[3]) : nil
            return Row(word: word, meaning: meaning, example: example, topik: topik)
        }
    }

    /// Serialisiert Vokabeln als CSV (Semikolon-getrennt), inkl. Header.
    static func export(_ vocabs: [Vocab]) -> String {
        var lines = ["word;meaning;example;topik;group;status"]
        for v in vocabs {
            let fields = [
                v.word,
                v.meaning,
                v.example ?? "",
                v.topikLevel?.abbreviation ?? "",
                v.group?.name ?? "",
                L(v.status.titleKey)
            ].map(escape)
            lines.append(fields.joined(separator: ";"))
        }
        return lines.joined(separator: "\n")
    }

    /// Dateiname-Präfix der Export-Dateien im Temp-Verzeichnis.
    private static let exportPrefix = "DailyHangul-Vokabeln-"

    /// Schreibt den Export als `.csv`-Datei ins temporäre Verzeichnis und gibt die
    /// URL zurück (zum Teilen via Share-Sheet). Wird erst beim tatsächlichen Teilen
    /// aufgerufen – nicht bei jeder View-Auswertung (siehe [[SettingsView]]).
    /// Ältere Export-Dateien werden vorher entfernt, damit sie sich (etwa pro Tag,
    /// wegen des Datums-Stamps) nicht im Temp-Verzeichnis ansammeln.
    static func exportFile(_ vocabs: [Vocab]) throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
        cleanupOldExports(in: tmp)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let stamp = formatter.string(from: .now)

        let url = tmp.appendingPathComponent("\(exportPrefix)\(stamp).csv")
        try export(vocabs).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// Entfernt zuvor erzeugte Export-Dateien (`DailyHangul-Vokabeln-*.csv`). Läuft
    /// vor dem Schreiben der neuen Datei, berührt also nie die gerade geteilte Datei.
    private static func cleanupOldExports(in dir: URL) {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.lastPathComponent.hasPrefix(exportPrefix)
            && file.pathExtension == "csv" {
            try? FileManager.default.removeItem(at: file)
        }
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
