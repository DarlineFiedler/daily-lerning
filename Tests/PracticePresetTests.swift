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

    // MARK: - Namens-Entdopplung (id(forName:in:))

    func testIdForNameReusesExistingCaseInsensitive() {
        let preset = sample(name: "Morgens")
        // Gleicher Name, andere Schreibung ⇒ dieselbe id (überschreiben).
        XCTAssertEqual(PracticePresetStore.id(forName: "morgens", in: [preset]), preset.id)
    }

    func testIdForNameCreatesNewWhenNoMatch() {
        let preset = sample(name: "Morgens")
        XCTAssertNotEqual(PracticePresetStore.id(forName: "Abends", in: [preset]), preset.id)
        XCTAssertNotEqual(PracticePresetStore.id(forName: "Abends", in: []), preset.id)
    }

    /// Zweimal unter demselben Namen speichern ⇒ nur ein (überschriebenes) Preset.
    func testSaveSameNameOverwritesInsteadOfDuplicating() {
        var first = sample(name: "Morgens")
        first.id = PracticePresetStore.id(forName: first.name, in: PracticePresetStore.all())
        PracticePresetStore.save(first)

        var second = sample(name: "morgens")   // andere Schreibung, andere Werte
        second.wordLimit = 50
        second.id = PracticePresetStore.id(forName: second.name, in: PracticePresetStore.all())
        PracticePresetStore.save(second)

        let all = PracticePresetStore.all()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.wordLimit, 50)
    }
}
