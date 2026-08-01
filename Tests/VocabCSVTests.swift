@testable import DailyHangul
import XCTest

final class VocabCSVTests: XCTestCase {

    func testParsesSemicolon() {
        let rows = VocabCSV.parse("가다;gehen;Beispiel")
        XCTAssertEqual(rows, [VocabCSV.Row(word: "가다", meaning: "gehen", example: "Beispiel")])
    }

    func testParsesCommaAndTab() {
        XCTAssertEqual(VocabCSV.parse("먹다,essen"), [VocabCSV.Row(word: "먹다", meaning: "essen", example: nil)])
        XCTAssertEqual(VocabCSV.parse("물\t Wasser"), [VocabCSV.Row(word: "물", meaning: "Wasser", example: nil)])
    }

    func testSkipsInvalidAndEmptyLines() {
        let rows = VocabCSV.parse("""
        가다;gehen

        nur-ein-feld
        먹다;essen
        """)
        XCTAssertEqual(rows.map(\.word), ["가다", "먹다"])
    }

    func testTrimsWhitespace() {
        let rows = VocabCSV.parse("  사과 ;  Apfel  ")
        XCTAssertEqual(rows, [VocabCSV.Row(word: "사과", meaning: "Apfel", example: nil)])
    }

    func testExportRoundTripsCoreFields() {
        let apple = Vocab(word: "사과", meaning: "Apfel", example: "Ein Beispiel")
        let csv = VocabCSV.export([apple])
        let lines = csv.split(separator: "\n")
        XCTAssertEqual(lines.first, "word;meaning;example;topik;group;status") // Header
        XCTAssertTrue(csv.contains("사과;Apfel;Ein Beispiel"))
    }

    // MARK: - TOPIK-Niveau (4. Spalte)

    func testParsesTopikLevel() {
        // Wort;Bedeutung;Beispiel(leer);TOPIK – römische Kurzform, groß-/kleinschreibungsegal.
        XCTAssertEqual(VocabCSV.parse("가다;gehen;;I").first?.topik, .one)
        XCTAssertEqual(VocabCSV.parse("가다;gehen;;ii").first?.topik, .two)
        // Beispiel + Niveau nebeneinander bleiben getrennt.
        let row = VocabCSV.parse("가다;gehen;Beispiel;II").first
        XCTAssertEqual(row?.example, "Beispiel")
        XCTAssertEqual(row?.topik, .two)
    }

    func testTopikMissingColumnIsNil() {
        XCTAssertNil(VocabCSV.parse("가다;gehen").first?.topik)
        XCTAssertNil(VocabCSV.parse("가다;gehen;Beispiel").first?.topik)
    }

    func testTopikInvalidValueIsNil() {
        XCTAssertNil(VocabCSV.parse("가다;gehen;;X").first?.topik)
        XCTAssertNil(VocabCSV.parse("가다;gehen;;7").first?.topik)
        XCTAssertNil(VocabCSV.parse("가다;gehen;; ").first?.topik)
    }

    func testTopikNumericLevelsMapToBands() {
        // Offizielle Level 1–2 ⇒ TOPIK I, 3–6 ⇒ TOPIK II.
        XCTAssertEqual(VocabCSV.parse("가다;gehen;;1").first?.topik, .one)
        XCTAssertEqual(VocabCSV.parse("가다;gehen;;2").first?.topik, .one)
        XCTAssertEqual(VocabCSV.parse("가다;gehen;;3").first?.topik, .two)
        XCTAssertEqual(VocabCSV.parse("가다;gehen;;6").first?.topik, .two)
    }

    func testExportIncludesTopikAndRoundTrips() {
        let vocab = Vocab(word: "사과", meaning: "Apfel", topik: .two)
        let csv = VocabCSV.export([vocab])
        XCTAssertTrue(csv.contains("사과;Apfel;;II"))
        XCTAssertEqual(VocabCSV.parse(csv).first?.topik, .two)
    }

    func testExportEscapesSemicolons() {
        let tricky = Vocab(word: "a;b", meaning: "x")
        let csv = VocabCSV.export([tricky])
        XCTAssertTrue(csv.contains("\"a;b\""))
    }

    func testSkipsExportHeaderRow() {
        // Eine exportierte Kopfzeile darf beim Re-Import nicht als Vokabel landen.
        let rows = VocabCSV.parse("word;meaning;example;group;status\n가다;gehen")
        XCTAssertEqual(rows, [VocabCSV.Row(word: "가다", meaning: "gehen", example: nil)])
    }

    func testParsesQuotedDelimiter() {
        // Trennzeichen innerhalb von Quotes zählt nicht; "" wird zu ".
        let rows = VocabCSV.parse("\"a;b\";\"sagt \"\"hallo\"\"\"")
        XCTAssertEqual(rows, [VocabCSV.Row(word: "a;b", meaning: "sagt \"hallo\"", example: nil)])
    }

    func testExportThenParseRoundTrips() {
        // Export → Parse ergibt die Kernfelder zurück (Header + Zusatzspalten ignoriert).
        let vocabs = [
            Vocab(word: "사과", meaning: "Apfel", example: "Ein Beispiel"),
            Vocab(word: "a;b", meaning: "x;y", example: nil)
        ]
        let parsed = VocabCSV.parse(VocabCSV.export(vocabs))
        XCTAssertEqual(parsed, [
            VocabCSV.Row(word: "사과", meaning: "Apfel", example: "Ein Beispiel"),
            VocabCSV.Row(word: "a;b", meaning: "x;y", example: nil)
        ])
    }

    func testExportFileWritesCSVWithIdenticalContent() throws {
        let vocabs = [
            Vocab(word: "사과", meaning: "Apfel", example: "Ein Beispiel"),
            Vocab(word: "a;b", meaning: "x;y", example: nil)
        ]
        let url = try VocabCSV.exportFile(vocabs)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertEqual(url.pathExtension, "csv")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        // Datei-Inhalt ist exakt der String-Export (nur on-demand als Datei geschrieben).
        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(content, VocabCSV.export(vocabs))
    }

    func testExportFileRemovesStaleExports() throws {
        // Simulierte Export-Datei eines früheren Tages im selben Temp-Verzeichnis.
        let stale = FileManager.default.temporaryDirectory
            .appendingPathComponent("DailyHangul-Vokabeln-2000-01-01.csv")
        try "alt".write(to: stale, atomically: true, encoding: .utf8)

        let url = try VocabCSV.exportFile([Vocab(word: "사과", meaning: "Apfel", example: nil)])
        defer { try? FileManager.default.removeItem(at: url) }

        // Die alte Datei wurde aufgeräumt, die neue existiert.
        XCTAssertFalse(FileManager.default.fileExists(atPath: stale.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }
}
