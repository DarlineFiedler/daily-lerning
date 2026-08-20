@testable import DailyHangul
import XCTest

final class TranslatorDirectionTests: XCTestCase {

    // MARK: Hangul-Erkennung

    func testDetectsHangulSyllables() {
        XCTAssertTrue(TranslationDirection.containsHangul("안녕하세요"))
        XCTAssertTrue(TranslationDirection.containsHangul("Hallo 사랑"))
    }

    func testNoHangulForLatinText() {
        XCTAssertFalse(TranslationDirection.containsHangul("Guten Morgen"))
        XCTAssertFalse(TranslationDirection.containsHangul("hello world 123"))
    }

    // MARK: Richtung

    func testKoreanInputTranslatesToAppLang() {
        let pair = TranslationDirection.pair(for: "사랑", appLang: "de", manualOverride: false)
        XCTAssertEqual(pair.source, "ko")
        XCTAssertEqual(pair.target, "de")
        XCTAssertEqual(pair.sourceTTS, "ko-KR")
        XCTAssertEqual(pair.targetTTS, "de-DE")
    }

    func testLatinInputTranslatesToKorean() {
        let pair = TranslationDirection.pair(for: "Liebe", appLang: "de", manualOverride: false)
        XCTAssertEqual(pair.source, "de")
        XCTAssertEqual(pair.target, "ko")
    }

    func testManualOverrideSwapsDirection() {
        let auto = TranslationDirection.pair(for: "Liebe", appLang: "en", manualOverride: false)
        let swapped = TranslationDirection.pair(for: "Liebe", appLang: "en", manualOverride: true)
        XCTAssertEqual(swapped.source, auto.target)
        XCTAssertEqual(swapped.target, auto.source)
    }

    // MARK: App-Sprach-Auflösung

    func testResolvedAppLangForFixedLanguages() {
        XCTAssertEqual(TranslationDirection.resolvedAppLang(language: .de, deviceCode: "fr"), "de")
        XCTAssertEqual(TranslationDirection.resolvedAppLang(language: .en, deviceCode: "fr"), "en")
    }

    func testResolvedAppLangFallsBackForKorean() {
        // UI Koreanisch → Gegenseite Englisch, da Ko↔Ko sinnlos ist.
        XCTAssertEqual(TranslationDirection.resolvedAppLang(language: .ko, deviceCode: "ko"), "en")
    }

    func testResolvedAppLangClampsSystem() {
        XCTAssertEqual(TranslationDirection.resolvedAppLang(language: .system, deviceCode: "de"), "de")
        XCTAssertEqual(TranslationDirection.resolvedAppLang(language: .system, deviceCode: "en"), "en")
        // Nicht unterstützte System-Sprache (und Koreanisch) → Englisch.
        XCTAssertEqual(TranslationDirection.resolvedAppLang(language: .system, deviceCode: "fr"), "en")
        XCTAssertEqual(TranslationDirection.resolvedAppLang(language: .system, deviceCode: "ko"), "en")
    }
}
