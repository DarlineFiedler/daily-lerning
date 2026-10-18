@testable import DailyHangul
import XCTest

final class WordPackTests: XCTestCase {

    /// `loadBundledCached()` liefert dasselbe Ergebnis wie der synchrone Loader und cacht es:
    /// ein zweiter Aufruf gibt identische Pakete zurück (Cache-Miss + Cache-Hit, Issue #142).
    @MainActor
    func testLoadBundledCachedMatchesSyncLoaderAndCaches() async {
        let sync = WordPack.loadBundled()

        let first = await WordPack.loadBundledCached()
        let second = await WordPack.loadBundledCached()

        XCTAssertEqual(first.map(\.id), sync.map(\.id))
        XCTAssertEqual(first.map(\.count), sync.map(\.count))
        // Zweiter Aufruf trifft den Cache und liefert das identische Ergebnis.
        XCTAssertEqual(first.map(\.id), second.map(\.id))
    }
}
