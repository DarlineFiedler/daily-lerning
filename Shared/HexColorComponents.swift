import Foundation

/// Reine (UIKit-/SwiftUI-freie) Zerlegung eines Hex-Farbstrings in RGBA-Kanäle (0…1).
/// Eine einzige Quelle der Wahrheit für das Hex-Format der App (`#RRGGBB` oder
/// `#RRGGBBAA`), damit `Color(hex:)` (Darstellung) und [[VocabGarden]] (abgeleitete
/// Blüten-Optik) nicht getrennt driften. `nil`, wenn der Wert keine parsebaren
/// 6/8 Hex-Stellen hat.
enum HexColorComponents {
    struct RGBA: Equatable {
        let red, green, blue, alpha: Double
    }

    static func parse(_ hex: String) -> RGBA? {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        guard Scanner(string: cleaned).scanHexInt64(&value) else { return nil }
        switch cleaned.count {
        case 6: // RRGGBB
            return RGBA(red: Double((value & 0xFF0000) >> 16) / 255,
                        green: Double((value & 0x00FF00) >> 8) / 255,
                        blue: Double(value & 0x0000FF) / 255,
                        alpha: 1)
        case 8: // RRGGBBAA
            return RGBA(red: Double((value & 0xFF00_0000) >> 24) / 255,
                        green: Double((value & 0x00FF_0000) >> 16) / 255,
                        blue: Double((value & 0x0000_FF00) >> 8) / 255,
                        alpha: Double(value & 0x0000_00FF) / 255)
        default:
            return nil
        }
    }
}
