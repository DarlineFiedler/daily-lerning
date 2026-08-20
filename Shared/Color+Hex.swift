import SwiftUI

extension Color {
    /// Erstellt eine Farbe aus einem Hex-String (z.B. "#FF8800" oder "FF8800").
    init(hex: String) {
        // Gemeinsamer Hex-Parser (siehe [[HexColorComponents]]); unparsebar → neutrales Grau.
        let c = HexColorComponents.parse(hex) ?? HexColorComponents.RGBA(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        self.init(.sRGB, red: c.red, green: c.green, blue: c.blue, opacity: c.alpha)
    }

    /// Liefert den Hex-String (#RRGGBB) der Farbe.
    var hexString: String {
        #if canImport(UIKit)
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X",
                      Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))
        #else
        return "#808080"
        #endif
    }
}

/// Vordefinierte Farbpalette für die Gruppen-Auswahl.
enum GroupPalette {
    static let colors: [String] = [
        "#EF4444", "#F97316", "#F59E0B", "#EAB308",
        "#84CC16", "#22C55E", "#10B981", "#14B8A6",
        "#06B6D4", "#3B82F6", "#6366F1", "#8B5CF6",
        "#A855F7", "#EC4899", "#F43F5E", "#78716C"
    ]

    static var random: String { colors.randomElement() ?? "#3B82F6" }
}
