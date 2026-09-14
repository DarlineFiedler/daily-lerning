import SwiftUI

/// Drei eingebettete Schriften der v3-Optik, konsequent nach Rolle eingesetzt:
/// - **Gowun Batang** (Serif) – Überschriften, Wörter, Buttons, Fließtext (400/700).
///   Enthält auch die koreanischen Glyphen.
/// - **Courier Prime** (Monospace) – Labels, Metadaten, Zähler, Tab-Titel (meist
///   `.tracking()` + Großbuchstaben).
/// - **Nanum Pen** (Handschrift) – Randnotizen/Kommentare, leicht rotiert.
///
/// PostScript-Namen sind fix (siehe App/Resources/Fonts, registriert via `UIAppFonts`
/// in project.yml). Alle Styles skalieren via `relativeTo:` mit Dynamic Type.
enum AppFont {
    static let serif = "GowunBatang-Regular"
    static let serifBold = "GowunBatang-Bold"
    static let mono = "CourierPrime-Regular"
    static let monoBold = "CourierPrime-Bold"
    static let hand = "NanumPen-Regular"
}

extension Font {
    // MARK: - Serif (Gowun Batang) – Titel & Text

    static let appLargeTitle = Font.custom(AppFont.serifBold, size: 30, relativeTo: .largeTitle)
    static let appTitle = Font.custom(AppFont.serifBold, size: 24, relativeTo: .title)
    static let appTitle2 = Font.custom(AppFont.serifBold, size: 21, relativeTo: .title2)
    static let appTitle3 = Font.custom(AppFont.serifBold, size: 18, relativeTo: .title3)
    static let appHeadline = Font.custom(AppFont.serifBold, size: 17, relativeTo: .headline)
    static let appBody = Font.custom(AppFont.serif, size: 15, relativeTo: .body)
    static let appSubheadline = Font.custom(AppFont.serif, size: 14, relativeTo: .subheadline)

    // MARK: - Monospace (Courier Prime) – Labels, Meta, Zähler

    /// Kleines Mono-Label (Meta/Datum) – am Aufrufort gern `.tracking(1)`.
    static let appCaption = Font.custom(AppFont.mono, size: 12, relativeTo: .caption)
    /// Mikro-Label (Tab-Titel, Badges).
    static let appMonoMicro = Font.custom(AppFont.mono, size: 10, relativeTo: .caption2)

    // MARK: - Große Anzeige-Schrift (Lernkarten / koreanisches Wort)

    /// Große, gerundete Anzeige-Schrift für Lernkarten (z.B. das koreanische Wort).
    static func appDisplay(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        let light: Set<Font.Weight> = [.ultraLight, .thin, .light, .regular, .medium]
        let name = light.contains(weight) ? AppFont.serif : AppFont.serifBold
        return .custom(name, size: size, relativeTo: .largeTitle)
    }

    /// Monospace in beliebiger Größe (Zähler, Fortschritt).
    static func appMono(_ size: CGFloat, bold: Bool = false, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(bold ? AppFont.monoBold : AppFont.mono, size: size, relativeTo: style)
    }

    /// Handschrift (Randnotizen). Am Aufrufort meist mit `.rotationEffect(.degrees(-2))`.
    static func appHand(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(AppFont.hand, size: size, relativeTo: style)
    }
}
