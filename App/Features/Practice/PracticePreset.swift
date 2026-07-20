import Foundation

/// Eine gespeicherte Lern-Voreinstellung. Enums werden als `rawValue` abgelegt,
/// damit die Speicherung stabil und vorwärtskompatibel bleibt.
struct PracticePreset: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var groupIDs: [UUID]
    var statuses: [Int]        // LearningStatus.rawValue
    var direction: String      // PracticeDirection.rawValue
    var modes: [String]        // PracticeMode.rawValue
    var wordLimit: Int?        // nil = alle
}

/// Lädt/speichert die Lern-Voreinstellungen als JSON in `UserDefaults.standard`.
/// App-lokal – wird (anders als die Widget-Einstellungen) nicht vom Widget gebraucht.
enum PracticePresetStore {
    private static let key = "practice.presets"
    private static var d: UserDefaults { .standard }

    static func all() -> [PracticePreset] {
        guard let data = d.data(forKey: key),
              let presets = try? JSONDecoder().decode([PracticePreset].self, from: data)
        else { return [] }
        return presets
    }

    /// Fügt ein Preset hinzu oder überschreibt ein vorhandenes mit gleicher `id`.
    static func save(_ preset: PracticePreset) {
        var presets = all()
        if let idx = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[idx] = preset
        } else {
            presets.append(preset)
        }
        persist(presets)
    }

    static func delete(_ preset: PracticePreset) {
        persist(all().filter { $0.id != preset.id })
    }

    /// Wählt die `id` für ein unter `name` zu speicherndes Preset: übernimmt die
    /// eines bereits vorhandenen, gleichnamigen (Groß-/Kleinschreibung egal)
    /// Presets, damit Speichern es überschreibt statt zu duplizieren – sonst eine
    /// neue `id`.
    static func id(forName name: String, in presets: [PracticePreset]) -> UUID {
        presets.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.id ?? UUID()
    }

    private static func persist(_ presets: [PracticePreset]) {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        d.set(data, forKey: key)
    }
}
