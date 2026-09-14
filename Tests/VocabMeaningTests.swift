@testable import DailyHangul
import XCTest

/// Prüft die mehrsprachigen Bedeutungs-Helfer auf `Vocab` (Issue #29):
/// Lookup mit Fallback, verfügbare Sprachen und das Setzen/Entfernen getaggter
/// Bedeutungen inkl. Code-Normalisierung.
final class VocabMeaningTests: XCTestCase {

    func testMeaningForNilLanguageReturnsPrimary() {
        let v = Vocab(word: "개", meaning: "Hund")
        v.meaningsByLanguage = ["en": "dog"]
        XCTAssertEqual(v.meaning(forLanguage: nil), "Hund")
    }

    func testMeaningForTaggedLanguageIsPreferred() {
        let v = Vocab(word: "개", meaning: "Hund")
        v.meaningsByLanguage = ["en": "dog"]
        XCTAssertEqual(v.meaning(forLanguage: "en"), "dog")
    }

    func testMeaningFallsBackWhenLanguageMissing() {
        let v = Vocab(word: "개", meaning: "Hund")
        v.meaningsByLanguage = ["en": "dog"]
        // Keine französische Bedeutung → Rückfall auf die Primärbedeutung.
        XCTAssertEqual(v.meaning(forLanguage: "fr"), "Hund")
    }

    func testMeaningFallsBackWhenTaggedValueEmpty() {
        let v = Vocab(word: "개", meaning: "Hund")
        v.meaningsByLanguage = ["en": ""]
        XCTAssertEqual(v.meaning(forLanguage: "en"), "Hund")
    }

    func testMeaningLookupNormalizesCode() {
        let v = Vocab(word: "개", meaning: "Hund")
        v.meaningsByLanguage = ["en": "dog"]
        XCTAssertEqual(v.meaning(forLanguage: " EN "), "dog")
        XCTAssertEqual(v.meaning(forLanguage: ""), "Hund")
    }

    func testAvailableMeaningLanguagesSortedAndNonEmptyOnly() {
        let v = Vocab(word: "개", meaning: "Hund")
        v.meaningsByLanguage = ["en": "dog", "fr": "chien", "es": ""]
        XCTAssertEqual(v.availableMeaningLanguages, ["en", "fr"]) // „es" leer → raus
    }

    func testSetMeaningNormalizesAndStores() {
        let v = Vocab(word: "개", meaning: "Hund")
        v.setMeaning(" dog ", forLanguage: " EN ")
        XCTAssertEqual(v.meaningsByLanguage, ["en": "dog"])
    }

    func testSetMeaningEmptyTextRemovesEntry() {
        let v = Vocab(word: "개", meaning: "Hund")
        v.setMeaning("dog", forLanguage: "en")
        v.setMeaning("   ", forLanguage: "en")
        XCTAssertTrue(v.meaningsByLanguage.isEmpty)
    }

    func testSetMeaningIgnoresEmptyCode() {
        let v = Vocab(word: "개", meaning: "Hund")
        v.setMeaning("dog", forLanguage: "   ")
        XCTAssertTrue(v.meaningsByLanguage.isEmpty)
    }

    // MARK: - JSON-Backing (Persistenz)

    /// Der berechnete Zugriff serialisiert/parst verlustfrei – auch mit mehreren Sprachen.
    func testMeaningsByLanguageRoundTripsThroughJSONBacking() {
        let v = Vocab(word: "개", meaning: "Hund")
        v.meaningsByLanguage = ["en": "dog", "fr": "chien"]
        XCTAssertEqual(v.meaningsByLanguage, ["en": "dog", "fr": "chien"])
        v.meaningsByLanguage = [:]
        XCTAssertEqual(v.meaningsByLanguage, [:])
    }

    // MARK: - Editor: unvollständige Übersetzungszeilen (Issue #29)

    func testIncompleteTranslationDetectsHalfFilledRows() {
        XCTAssertTrue(VocabEditView.hasIncompleteTranslation([("en", "")])) // Code ohne Text
        XCTAssertTrue(VocabEditView.hasIncompleteTranslation([("", "dog")])) // Text ohne Code
        XCTAssertTrue(VocabEditView.hasIncompleteTranslation([(" ", "dog")])) // nur Whitespace-Code
    }

    func testIncompleteTranslationAcceptsCompleteOrEmptyRows() {
        XCTAssertFalse(VocabEditView.hasIncompleteTranslation([]))
        XCTAssertFalse(VocabEditView.hasIncompleteTranslation([("en", "dog")]))
        XCTAssertFalse(VocabEditView.hasIncompleteTranslation([("", "")])) // ganz leer = ok (wird verworfen)
        XCTAssertFalse(VocabEditView.hasIncompleteTranslation([("en", "dog"), ("fr", "chien")]))
    }
}
