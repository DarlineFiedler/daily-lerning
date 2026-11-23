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

    func testBlankedReplacesEveryOccurrence() {
        // Kommt das Wort mehrfach vor, darf kein Treffer die Antwort verraten.
        XCTAssertEqual(ClozeText.blanked(example: "가다 가다", word: "가다"),
                       "\(ClozeText.blank) \(ClozeText.blank)")
    }

    func testCanClozeRequiresWordInExample() {
        // Wort kommt wörtlich vor → abfragbar.
        XCTAssertTrue(ClozeText.canCloze(Vocab(word: "가다", meaning: "gehen", example: "학교에 가다")))
        // Nur gebeugte Form im Satz → die Lücke würde die Antwort zeigen → nicht abfragbar.
        XCTAssertFalse(ClozeText.canCloze(Vocab(word: "가다", meaning: "gehen", example: "학교에 갔어요")))
        // Kein Beispielsatz → nicht abfragbar.
        XCTAssertFalse(ClozeText.canCloze(Vocab(word: "가다", meaning: "gehen")))
    }

    // MARK: - Wortgrenzen & Partikel (Issue #133)

    func testWordInsideLongerWordIsNotClozed() {
        // `가` steckt in `가방` – das ist ein anderes Wort, keine Lücke.
        let vocab = Vocab(word: "가", meaning: "g", example: "가방에 넣어요")
        XCTAssertFalse(ClozeText.canCloze(vocab))
        XCTAssertEqual(ClozeText.blanked(example: "가방에 넣어요", word: "가"), "가방에 넣어요")
    }

    func testWordInMiddleOfTokenIsNotClozed() {
        XCTAssertFalse(ClozeText.canCloze(Vocab(word: "교", meaning: "x", example: "학교에 가요")))
    }

    func testParticleIsBlankedTogetherWithWord() {
        // Die angehängte Partikel verschwindet mit – sie würde sonst grammatische Info leaken.
        let vocab = Vocab(word: "학교", meaning: "Schule", example: "학교에 가요.")
        XCTAssertTrue(ClozeText.canCloze(vocab))
        XCTAssertEqual(ClozeText.blanked(example: "학교에 가요.", word: "학교"),
                       "\(ClozeText.blank) 가요.")
    }

    func testParticleCombinationIsRecognized() {
        XCTAssertEqual(ClozeText.blanked(example: "학교에서는 공부해요", word: "학교"),
                       "\(ClozeText.blank) 공부해요")
    }

    func testPunctuationAroundTokenIsKept() {
        XCTAssertEqual(ClozeText.blanked(example: "저는 \"학교\".", word: "학교"),
                       "저는 \"\(ClozeText.blank)\".")
    }

    func testNonParticleRemainderIsNotClozed() {
        // `차이가`: Rest `이가` ist keine Partikel → `차` kommt nicht als eigenes Wort vor.
        XCTAssertFalse(ClozeText.canCloze(Vocab(word: "차", meaning: "Auto", example: "차이가 있어요")))
    }

    func testParticleMustFitFinalConsonant() {
        // `차` endet auf Vokal → Subjektpartikel wäre `가`, nicht `이`; `차이` ist ein eigenes Wort.
        XCTAssertFalse(ClozeText.matches(core: "차이", word: "차"))
        XCTAssertTrue(ClozeText.matches(core: "차가", word: "차"))
        // `책` endet auf Konsonant → `을`, nicht `를`.
        XCTAssertTrue(ClozeText.matches(core: "책을", word: "책"))
        XCTAssertFalse(ClozeText.matches(core: "책를", word: "책"))
    }

    func testRieulFinalTakesVowelFormOfRo() {
        XCTAssertTrue(ClozeText.matches(core: "서울로", word: "서울"))
        XCTAssertFalse(ClozeText.matches(core: "서울으로", word: "서울"))
        XCTAssertTrue(ClozeText.matches(core: "집으로", word: "집"))
    }

    func testNonHangulWordAcceptsEitherParticleForm() {
        XCTAssertTrue(ClozeText.matches(core: "Coffee를", word: "coffee"))
        XCTAssertTrue(ClozeText.matches(core: "Coffee을", word: "coffee"))
    }

    func testPunctuationOnlyTokensAreSkipped() {
        XCTAssertEqual(ClozeText.blanked(example: "학교 - 학교!", word: "학교"),
                       "\(ClozeText.blank) - \(ClozeText.blank)!")
    }

    func testBlankedWithEmptyWordKeepsSentence() {
        XCTAssertEqual(ClozeText.blanked(example: "학교에 가요", word: "  "), "학교에 가요")
        XCTAssertFalse(ClozeText.canCloze(Vocab(word: " ", meaning: "x", example: "학교에 가요")))
    }
}
