@testable import DailyHangul
import XCTest

/// Prüft die reine Lückentext-Logik (ohne UI): brauchbare Beispielsätze erkennen
/// und das gesuchte Wort im Satz durch eine Lücke ersetzen.
final class ClozeTextTests: XCTestCase {
    func testUsableExampleReturnsTrimmedNonEmpty() {
        let vocab = Vocab(word: "가다", meaning: "gehen", example: "  학교에 가다  ")
        XCTAssertEqual(ClozeText.usableExample(for: vocab), "학교에 가다")
    }

    func testUsableExampleNilForMissing() {
        XCTAssertNil(ClozeText.usableExample(for: Vocab(word: "가", meaning: "g")))
    }

    func testUsableExampleNilForBlank() {
        XCTAssertNil(ClozeText.usableExample(for: Vocab(word: "가", meaning: "g", example: "   ")))
    }

    func testBlankedReplacesWordWithGap() {
        XCTAssertEqual(ClozeText.blanked(example: "학교에 가다", word: "가다"),
                       "학교에 \(ClozeText.blank)")
    }

    func testBlankedIsCaseInsensitive() {
        XCTAssertEqual(ClozeText.blanked(example: "I Go home", word: "go"),
                       "I \(ClozeText.blank) home")
    }

    func testBlankedKeepsSentenceWhenWordAbsent() {
        // Gebeugte Form: das Grundwort steht nicht wörtlich im Satz → ganzer Satz bleibt.
        XCTAssertEqual(ClozeText.blanked(example: "학교에 갔어요", word: "가다"), "학교에 갔어요")
    }
}
