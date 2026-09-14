import SwiftUI

/// Zentrale Design-Tokens der v3-Optik **„Papier & Tinte / Gartenkarte"**.
/// Die App sieht aus wie ein handbeschriftetes Gartentagebuch: warmes Papier,
/// Zinnober- und Blattgrün-Akzente, kleine Radien (4pt) und **harte Offset-Schatten
/// ohne Blur** (Print-Look).
///
/// Wichtig: Die bisherigen Token-Namen (`brandStart`, `background`, `Radius.card`,
/// `Spacing`, `statusLearned` …) bleiben erhalten, damit der gesamte Bestandscode
/// weiter kompiliert – sie zeigen nur auf die neuen Werte. Neue Screens nutzen
/// zusätzlich die semantischen Tokens weiter unten (`paper`, `ink`, `vermillion` …).
enum Theme {

    // MARK: - Papier & Tinte – semantische Farben (adaptiv Light/Dark)

    /// App-Hintergrund: warmes Papier. Dark: tiefe Tinte.
    static let paper = adaptive(light: "#F2E9D8", dark: "#14120F")
    /// Karten, Listenzeilen, Eingabefelder.
    static let card = adaptive(light: "#FBF5EA", dark: "#211E19")
    /// Tiefere Kartenfläche (unterer Gradient der Gartenkarte).
    static let cardDeep = adaptive(light: "#F0E4CC", dark: "#1B1813")

    /// Primärtext (Tinte). Dark: helles Papier.
    static let ink = adaptive(light: "#211E19", dark: "#F2E9D8")
    /// Sekundärtext (~55 % Tinte).
    static let inkSecondary = adaptive(light: "#211E19", dark: "#F2E9D8").opacity(0.55)
    /// Labels/Meta (~45 % Tinte).
    static let inkMuted = adaptive(light: "#211E19", dark: "#F2E9D8").opacity(0.45)
    /// Deaktiviert (~40 % Tinte).
    static let inkFaint = adaptive(light: "#211E19", dark: "#F2E9D8").opacity(0.40)

    /// Rahmen aktiv (~20 %) / ruhig (~12 %).
    static let hairline = adaptive(light: "#211E19", dark: "#F2E9D8").opacity(0.12)
    static let hairlineStrong = adaptive(light: "#211E19", dark: "#F2E9D8").opacity(0.20)

    /// Zinnober – Primär-CTA („Üben"), Streak, Notizen, Warnungen.
    static let vermillion = Color(hex: "#B23A2C")
    /// Zinnober dunkel – Hard-Shadow unter Primärbuttons, Fehlertext.
    static let vermillionDark = Color(hex: "#8E2C20")
    /// Blattgrün – Erfolg, Fortschritt, „Weiter"-Button.
    static let leaf = Color(hex: "#4F7043")
    /// Blattgrün dunkel – Hard-Shadow unter Erfolgsbuttons.
    static let leafDark = Color(hex: "#3C5633")
    /// Text auf grünem Tönungsfeld.
    static let leafText = Color(hex: "#2F4A26")
    /// Ocker – dritte Gruppenfarbe, Hinweise, Sticker.
    static let ocher = Color(hex: "#C98A2B")
    /// Nacht – dunkler Screen (Sperrbildschirm, Endgegner).
    static let night = Color(hex: "#14120F")

    // MARK: - Marken-Kompatibilität (Bestandscode)
    // Früher Indigo→Pink-Verlauf. Jetzt auf die Papier-Palette umgemünzt, damit alte
    // Aufrufer denselben Namen verwenden können.

    static let brandStart = vermillion
    static let brandMid = Color(hex: "#C0503F")
    static let brandEnd = vermillionDark

    /// Zentraler Akzent-Verlauf (nun ein ruhiger Zinnober-Verlauf statt Regenbogen).
    static let brandGradient = LinearGradient(
        colors: [vermillion, vermillionDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Weicher Verlauf für große Flächen (z.B. Gartenkarte Papier → Papier-tief).
    static let brandGradientSoft = LinearGradient(
        colors: [card, cardDeep],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Adaptive Flächenfarben (Bestandsnamen → neue Werte)

    static let background = paper
    static let surface = card
    static let surfaceMuted = cardDeep

    // MARK: - Lern-Status-Farben (Pflanzenstufen), adaptiv
    // Genutzt via `LearningStatus.color`. Erdige Töne passend zum Garten.

    static let statusNew = adaptive(light: "#9A8F79", dark: "#7C725E") // Samen 🌰 – neutral
    static let statusLearning = ocher // Keimling 🌱
    static let statusAlmostLearned = adaptive(light: "#6E8F5B", dark: "#88A874") // Blatt 🌿
    static let statusLearned = leaf // Blüte 🌸

    /// Signalfarbe für falsche Antworten.
    static let wrong = vermillion

    // MARK: - Radien (Papier: klein, keine iOS-Cards)

    enum Radius {
        static let card: CGFloat = 4
        static let button: CGFloat = 4
        static let chip: CGFloat = 4
        static let pill: CGFloat = 999
    }

    // MARK: - Abstände

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
    }

    // MARK: - Schatten
    // Bestands-`Shadow` (weicher Blur) bleibt für Alt-Aufrufer, aber deutlich dezenter.
    // Neue Screens nutzen `HardShadow` (siehe PaperStyle.swift) für den Print-Look.

    enum Shadow {
        static let color = Color(hex: "#211E19").opacity(0.09)
        static let radius: CGFloat = 0
        static let x: CGFloat = 2
        static let y: CGFloat = 3
    }

    // MARK: - Helfer

    /// Baut eine an Light/Dark angepasste Farbe aus zwei Hex-Werten.
    static func adaptive(light: String, dark: String) -> Color {
        #if canImport(UIKit)
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(Color(hex: dark))
                : UIColor(Color(hex: light))
        })
        #else
        Color(hex: light)
        #endif
    }
}
