import XCTest
@testable import DailyHangul

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
        XCTAssertEqual(lines.first, "word;meaning;example;group;status")   // Header
        XCTAssertTrue(csv.contains("사과;Apfel;Ein Beispiel"))
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
            Vocab(word: "a;b", meaning: "x;y", example: nil),
        ]
        let parsed = VocabCSV.parse(VocabCSV.export(vocabs))
        XCTAssertEqual(parsed, [
            VocabCSV.Row(word: "사과", meaning: "Apfel", example: "Ein Beispiel"),
            VocabCSV.Row(word: "a;b", meaning: "x;y", example: nil),
        ])
    }
}
