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
        /// Zusätzliche, sprachgetaggte Bedeutungen (Sprachcode → Bedeutung), nur aus dem
        /// header-gesteuerten Format mit `meaning:<code>`-Spalten. Leer für das bisherige
        /// positionsbasierte Single-Language-Format (Issue #29).
        let meaningsByLanguage: [String: String]

        init(word: String, meaning: String, example: String?, topik: TopikLevel? = nil,
             meaningsByLanguage: [String: String] = [:]) {
            self.word = word
            self.meaning = meaning
            self.example = example
            self.topik = topik
            self.meaningsByLanguage = meaningsByLanguage
        }
    }

    /// Zerlegt eingefügten Text in Zeilen. Leere Zeilen und Zeilen ohne Bedeutung werden
    /// übersprungen. Erkennt das Trennzeichen pro Zeile automatisch und respektiert
    /// per `"…"` gequotete Felder (inkl. `""`-Escaping), sodass ein Export wieder
    /// eingelesen werden kann. (Feldinterne Zeilenumbrüche werden nicht unterstützt.)
    ///
    /// Zwei Formate werden unterstützt:
    /// - **Header-gesteuert**: Ist die erste Zeile eine Kopfzeile mit den Spalten `word`
    ///   und `meaning` (z.B. aus dem Export), werden die Spalten benannt zugeordnet. So
    ///   lassen sich sprachgetaggte Bedeutungen über `meaning:<code>`-Spalten (z.B.
    ///   `meaning:en`) einlesen (Issue #29). Zusätzliche Spalten (`group`, `status`)
    ///   werden ignoriert.
    /// - **Positionsbasiert** (bisheriges Single-Language-Format): ohne Kopfzeile gilt die
    ///   feste Reihenfolge Wort, Bedeutung, Beispiel (optional), TOPIK (optional).
    static func parse(_ text: String) -> [Row] {
        let lines = text.split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard let first = lines.first else { return [] }

        if let header = headerMapping(for: first) {
            return lines.dropFirst().compactMap { parseRow($0, header: header) }
        }
        return lines.compactMap(parsePositionalRow)
    }

    /// Baut aus einer möglichen Kopfzeile eine Spaltenname→Index-Zuordnung. Gibt `nil`
    /// zurück, wenn die Zeile keine Kopfzeile ist (kein `word`- **und** `meaning`-Feld) –
    /// dann greift der positionsbasierte Pfad. Spaltennamen werden kleingeschrieben.
    private static func headerMapping(for line: String) -> [String: Int]? {
        let names = splitFields(line, delimiter: delimiter(for: line))
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        var map: [String: Int] = [:]
        for (index, name) in names.enumerated() where !name.isEmpty && map[name] == nil {
            map[name] = index
        }
        guard map["word"] != nil, map["meaning"] != nil else { return nil }
        return map
    }

    /// Liest eine Datenzeile im header-gesteuerten Format anhand der Spaltenzuordnung.
    private static func parseRow(_ raw: String, header: [String: Int]) -> Row? {
        let fields = splitFields(raw, delimiter: delimiter(for: raw))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .map(deneutralizeFormula)

        func field(_ name: String) -> String? {
            guard let index = header[name], index < fields.count else { return nil }
            let value = fields[index]
            return value.isEmpty ? nil : value
        }

        guard let word = field("word"), let meaning = field("meaning") else { return nil }
        let example = field("example")
        let topik = field("topik").flatMap { TopikLevel(csv: $0) }

        var meanings: [String: String] = [:]
        for (name, index) in header where name.hasPrefix("meaning:") {
            let code = Vocab.normalizeLanguageCode(String(name.dropFirst("meaning:".count)))
            guard !code.isEmpty, index < fields.count else { continue }
            let value = fields[index]
            guard !value.isEmpty else { continue }
            meanings[code] = value
        }

        return Row(word: word, meaning: meaning, example: example, topik: topik,
                   meaningsByLanguage: meanings)
    }

    /// Liest eine Zeile im positionsbasierten Single-Language-Format (Wort, Bedeutung,
    /// Beispiel, TOPIK). Überspringt eine evtl. mitkopierte `word;meaning`-Kopfzeile.
    private static func parsePositionalRow(_ raw: String) -> Row? {
        let fields = splitFields(raw, delimiter: delimiter(for: raw))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .map(deneutralizeFormula)

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

    /// Serialisiert Vokabeln als CSV (Semikolon-getrennt), inkl. Header.
    ///
    /// Enthält keine Vokabel sprachgetaggte Bedeutungen, entsteht **exakt** das bisherige
    /// Single-Language-Format. Sobald mindestens eine getaggte Sprache vorkommt, wird je
    /// Sprache eine `meaning:<code>`-Spalte ergänzt (stabil sortiert); der Re-Import über
    /// `parse` erkennt dieses Format am Header (Issue #29).
    static func export(_ vocabs: [Vocab]) -> String {
        let languages: [String] = Set(vocabs.flatMap(\.availableMeaningLanguages)).sorted()

        var headerColumns: [String] = ["word", "meaning"]
        headerColumns += languages.map { "meaning:\($0)" }
        headerColumns += ["example", "topik", "group", "status"]

        var lines: [String] = [headerColumns.joined(separator: ";")]
        for v in vocabs {
            var fields: [String] = [v.word, v.meaning]
            fields += languages.map { v.meaningsByLanguage[$0] ?? "" }
            fields += [v.example ?? "", v.topikLevel?.abbreviation ?? "", v.group?.name ?? "", L(v.status.titleKey)]
            lines.append(fields.map(escape).joined(separator: ";"))
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
        // Über `Data` schreiben, um `.completeFileProtection` setzen zu können
        // (`String.write` kennt keine Protection-Option). Inhalt bleibt identischer
        // UTF-8-Text; auf dem Simulator ist der Dateischutz ein No-Op.
        try Data(export(vocabs).utf8).write(to: url, options: [.atomic, .completeFileProtection])
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

    /// Zeichen, die eine Zelle in Excel/Numbers/Google Sheets als Formel starten lassen.
    /// Beginnt ein Feld damit, wird es beim Export entschärft (CSV-/Formula-Injection).
    private static let formulaTriggers: Set<Character> = ["=", "+", "-", "@", "\t", "\r"]

    /// Feld für CSV-Export absichern: erst gegen Formula-Injection neutralisieren,
    /// dann bei Sonderzeichen in Anführungszeichen setzen.
    private static func escape(_ field: String) -> String {
        let safe = neutralizeFormula(field)
        guard safe.contains(";") || safe.contains("\"") || safe.contains("\n") else { return safe }
        return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// Verhindert CSV-/Formula-Injection: beginnt ein Feld mit einem Trigger-Zeichen
    /// (`= + - @`, Tab, CR), wird ein führendes `'` vorangestellt, sodass Tabellen-
    /// programme die Zelle als Text und nicht als Formel auswerten. Vokabeln können aus
    /// fremden, geteilten CSVs stammen und landen unverändert im (zum Teilen gedachten)
    /// Export – der Angriffsinhalt würde sonst mitreisen (siehe Issue #102).
    private static func neutralizeFormula(_ field: String) -> String {
        guard let first = field.first, formulaTriggers.contains(first) else { return field }
        return "'" + field
    }

    /// Kehrt `neutralizeFormula` beim Import um: ein führendes `'`, das nur einem
    /// Trigger-Zeichen vorangestellt wurde, wird wieder entfernt – so überlebt ein
    /// exportiertes Feld (z.B. die Grammatik-Endung „-습니다") den Re-Import unverändert.
    /// Ein echtes Apostroph (etwa „'cause") bleibt erhalten, weil danach kein
    /// Trigger-Zeichen folgt.
    private static func deneutralizeFormula(_ field: String) -> String {
        guard field.first == "'" else { return field }
        let rest = field.dropFirst()
        guard let next = rest.first, formulaTriggers.contains(next) else { return field }
        return String(rest)
    }
}
