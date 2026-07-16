import SwiftUI

/// Durchgängig abgerundete Schrift (`.rounded`) für den freundlichen, verspielten Look.
extension Font {
    static let appLargeTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let appTitle      = Font.system(.title, design: .rounded).weight(.bold)
    static let appTitle2     = Font.system(.title2, design: .rounded).weight(.semibold)
    static let appTitle3     = Font.system(.title3, design: .rounded).weight(.semibold)
    static let appHeadline   = Font.system(.headline, design: .rounded).weight(.semibold)
    static let appBody       = Font.system(.body, design: .rounded)
    static let appSubheadline = Font.system(.subheadline, design: .rounded)
    static let appCaption    = Font.system(.caption, design: .rounded)

    /// Große, gerundete Anzeige-Schrift für Lernkarten (z.B. das koreanische Wort).
    static func appDisplay(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
