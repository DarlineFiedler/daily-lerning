import XCTest
@testable import DailyHangul

/// Prüft die Lern-Voreinstellungen: Codable-Round-Trip und den UserDefaults-Store.
final class PracticePresetTests: XCTestCase {

    private let key = "practice.presets"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: key)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: key)
        super.tearDown()
    }

    private func sample(name: String = "Morgens") -> PracticePreset {
        PracticePreset(
            name: name,
            groupIDs: [UUID(), UUID()],
            statuses: [LearningStatus.learning.rawValue, LearningStatus.new.rawValue],
            direction: PracticeDirection.meaningToWord.rawValue,
            modes: [PracticeMode.writing.rawValue, PracticeMode.listening.rawValue],
            wordLimit: 20
        )
    }

    func testCodableRoundTrip() throws {
        let preset = sample()
        let data = try JSONEncoder().encode(preset)
        let decoded = try JSONDecoder().decode(PracticePreset.self, from: data)
        XCTAssertEqual(decoded, preset)
    }

    func testSaveAndLoad() {
        let preset = sample()
        PracticePresetStore.save(preset)
        let all = PracticePresetStore.all()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first, preset)
    }

    func testSaveUpsertsById() {
        var preset = sample(name: "Original")
        PracticePresetStore.save(preset)
        preset.name = "Geändert"
        PracticePresetStore.save(preset)

        let all = PracticePresetStore.all()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.name, "Geändert")
    }

    func testDelete() {
        let a = sample(name: "A")
        let b = sample(name: "B")
        PracticePresetStore.save(a)
        PracticePresetStore.save(b)
        PracticePresetStore.delete(a)

        let all = PracticePresetStore.all()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.name, "B")
    }

    func testEmptyWhenNothingStored() {
        XCTAssertTrue(PracticePresetStore.all().isEmpty)
    }
}
