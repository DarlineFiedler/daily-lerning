@testable import DailyHangul
import XCTest

final class EmojiSuggestionServiceTests: XCTestCase {

    // MARK: - Treffer

    func testSuggestsForExactMeaning() {
        XCTAssertEqual(EmojiSuggestionService.suggest(for: "Katze"), "🐱")
        XCTAssertEqual(EmojiSuggestionService.suggest(for: "Hund"), "🐶")
        XCTAssertEqual(EmojiSuggestionService.suggest(for: "Apfel"), "🍎")
    }

    // MARK: - Kein Treffer

    func testNoMatchReturnsNil() {
        XCTAssertNil(EmojiSuggestionService.suggest(for: "Xylofon"))
        XCTAssertNil(EmojiSuggestionService.suggest(for: "irgendein Fantasiewort"))
    }

    func testEmptyOrWhitespaceReturnsNil() {
        XCTAssertNil(EmojiSuggestionService.suggest(for: ""))
        XCTAssertNil(EmojiSuggestionService.suggest(for: "   \n  "))
    }

    // MARK: - Groß-/Kleinschreibung & Whitespace

    func testCaseInsensitive() {
        XCTAssertEqual(EmojiSuggestionService.suggest(for: "katze"), "🐱")
        XCTAssertEqual(EmojiSuggestionService.suggest(for: "KATZE"), "🐱")
        XCTAssertEqual(EmojiSuggestionService.suggest(for: "KaTzE"), "🐱")
    }

    func testTrimsAndCollapsesWhitespace() {
        XCTAssertEqual(EmojiSuggestionService.suggest(for: "  Katze  "), "🐱")
        let collapsed = EmojiSuggestionService.suggest(for: "koreanisches   essen")
        XCTAssertEqual(collapsed, EmojiSuggestionService.suggest(for: "koreanisches essen"))
    }

    // MARK: - Mehrfachbedeutungen (Synonyme) & Mehrwort-Bedeutungen

    func testMatchesOneOfSeveralCommaSeparatedMeanings() {
        // "Reis, Mahlzeit" – beide Teile sind hinterlegt; der erste Treffer gewinnt.
        XCTAssertEqual(EmojiSuggestionService.suggest(for: "Reis, Mahlzeit"), "🍚")
    }

    func testMatchesWordWithinMultiWordMeaning() {
        // Kein Treffer für die ganze Zeichenkette, aber für ein enthaltenes Wort.
        XCTAssertEqual(EmojiSuggestionService.suggest(for: "koreanisches Essen"), "🍽️")
    }

    func testIgnoresTrailingPunctuation() {
        // Anhängende Satzzeichen dürfen den Wort-Treffer nicht verhindern.
        XCTAssertEqual(EmojiSuggestionService.suggest(for: "Katze!"), "🐱")
        XCTAssertEqual(EmojiSuggestionService.suggest(for: "der kleine Hund."), "🐶")
    }

    // MARK: - Mehrdeutigkeiten deterministisch

    func testAmbiguityIsDeterministicLeftToRight() {
        // Enthält zwei hinterlegte Begriffe – der linke ("Hund") muss gewinnen und
        // das Ergebnis über wiederholte Aufrufe stabil bleiben.
        let meaning = "Hund und Katze"
        let first = EmojiSuggestionService.suggest(for: meaning)
        XCTAssertEqual(first, "🐶")
        XCTAssertEqual(EmojiSuggestionService.suggest(for: meaning), first)
    }
}
