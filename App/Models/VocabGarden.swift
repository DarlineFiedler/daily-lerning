import Foundation

/// Abgeleitete Darstellungsdaten für die spielerische „Garten"-Ansicht einer Gruppe
/// (Issue #92): jedes Wort ist eine Pflanze, deren Wachstumsstufe direkt am
/// `LearningStatus` hängt. Rein aus den Vokabeln berechnet – keine eigene Datenquelle,
/// keine Persistenz. Bewusst als eigenständiges, testbares Wertobjekt gehalten, während
/// die reine Darstellung in [[VocabGardenView]] liegt.
struct VocabGarden {
    /// Ab dieser Wortzahl zeigt die Ansicht eine Zusammenfassung (Anzahl je Stufe) statt
    /// jeder Einzelpflanze – hält sehr große Gruppen (>200 Wörter) flüssig.
    static let tileLimit = 120

    /// Verteilung der Lernstufen (sparse – über `count(of:)` lesen).
    let counts: [LearningStatus: Int]
    /// Gesamtzahl der Wörter.
    let total: Int

    init(vocabs: [Vocab]) {
        counts = vocabs.statusCounts()
        total = vocabs.count
    }

    func count(of status: LearningStatus) -> Int { counts[status] ?? 0 }

    /// Voll erblühter Garten: mindestens ein Wort und alle davon „gelernt".
    var isFullyBloomed: Bool {
        total > 0 && count(of: .learned) == total
    }

    /// Bei großen Gruppen wird statt Einzelpflanzen eine Zusammenfassung gezeigt.
    var showsSummary: Bool { total > Self.tileLimit }

    // MARK: - Pflanzen-Optik

    /// Emoji einer einzelnen Pflanze: Stufen unter „gelernt" nutzen das einheitliche
    /// Wachstums-Set (siehe [[LearningStatus]] `gardenStageEmoji`), die finale Blüte wird
    /// an die Gruppenfarbe gekoppelt (`bloomEmoji`).
    static func plantEmoji(for status: LearningStatus, groupHex: String) -> String {
        status == .learned ? bloomEmoji(forHex: groupHex) : status.gardenStageEmoji
    }

    /// Wählt eine Blüte passend zur Gruppenfarbe – so bekommt jede Gruppe ihre eigene
    /// „Pflanzenart", ohne dass eine zweite Datenquelle nötig wäre. Rein aus dem
    /// Farbton (Hue) des Hex-Werts abgeleitet; sehr blasse/graue Farben bekommen die
    /// neutrale Standardblüte.
    static func bloomEmoji(forHex hex: String) -> String {
        guard let hsv = hsv(fromHex: hex) else { return "🌼" }
        // Wenig gesättigte Farben (Grautöne) haben keinen aussagekräftigen Farbton.
        guard hsv.saturation >= 0.15 else { return "🌼" }
        switch hsv.hue {
        case ..<45: return "🌷" // Rot–Orange
        case ..<90: return "🌻" // Gelb–Limette
        case ..<160: return "🌼" // Grün
        case ..<210: return "🌸" // Türkis–Cyan
        case ..<285: return "🪻" // Blau–Violett
        default: return "🌺" // Magenta–Pink–Rot
        }
    }

    // MARK: - Farb-Hilfen (rein, ohne UIKit)

    /// Farbton (0…360) und Sättigung (0…1) eines Hex-Strings. `nil`, wenn der Wert
    /// keine parsebaren 6/8 Hex-Stellen hat. Rein arithmetisch (ohne UIKit), damit testbar.
    static func hsv(fromHex hex: String) -> (hue: Double, saturation: Double)? {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        guard Scanner(string: cleaned).scanHexInt64(&value) else { return nil }
        let r, g, b: Double
        switch cleaned.count {
        case 6:
            r = Double((value & 0xFF0000) >> 16) / 255
            g = Double((value & 0x00FF00) >> 8) / 255
            b = Double(value & 0x0000FF) / 255
        case 8:
            r = Double((value & 0xFF00_0000) >> 24) / 255
            g = Double((value & 0x00FF_0000) >> 16) / 255
            b = Double((value & 0x0000_FF00) >> 8) / 255
        default:
            return nil
        }
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let delta = maxC - minC
        let saturation = maxC <= 0 ? 0 : delta / maxC
        guard delta > 0 else { return (0, saturation) }
        let hue: Double
        switch maxC {
        case r: hue = 60 * ((g - b) / delta).truncatingRemainder(dividingBy: 6)
        case g: hue = 60 * ((b - r) / delta + 2)
        default: hue = 60 * ((r - g) / delta + 4)
        }
        return (hue < 0 ? hue + 360 : hue, saturation)
    }
}
