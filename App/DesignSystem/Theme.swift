import SwiftUI

/// Zentrale Design-Tokens (Farben, Radien, Abstände, Schatten) für das
/// bunte, verspielte Erscheinungsbild. Ersetzt die System-„Einstellungen"-Optik.
enum Theme {

    // MARK: - Marken-Farben

    /// Primäre Markenfarbe (Indigo) – auch als AccentColor hinterlegt.
    static let brandStart = Color(hex: "#6366F1") // Indigo
    static let brandMid = Color(hex: "#A855F7") // Violett
    static let brandEnd = Color(hex: "#EC4899") // Pink

    /// Der zentrale Marken-Verlauf für CTAs, Header und Akzente.
    static let brandGradient = LinearGradient(
        colors: [brandStart, brandMid, brandEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Weicherer Verlauf für große Flächen (Home-Header).
    static let brandGradientSoft = LinearGradient(
        colors: [brandStart.opacity(0.95), brandEnd.opacity(0.95)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Adaptive Flächenfarben (Light/Dark)

    /// App-Hintergrund – helles, leicht kühles Weiß bzw. tiefes Anthrazit.
    static let background = adaptive(light: "#F5F5FB", dark: "#0E0E13")

    /// Karten-/Oberflächenfarbe.
    static let surface = adaptive(light: "#FFFFFF", dark: "#1B1B22")

    /// Leicht abgesetzte Fläche (z.B. Chips, Balken-Hintergrund).
    static let surfaceMuted = adaptive(light: "#EEEEF5", dark: "#26262F")

    // MARK: - Semantische Farben (adaptiv, Light/Dark)

    /// Lern-Status-Farben – zentral hier, damit sie in Dark Mode angepasst sind
    /// (statt fest verdrahtet in der Models-Schicht). Genutzt via `LearningStatus.color`.
    static let statusNew = adaptive(light: "#94A3B8", dark: "#64748B")
    static let statusLearning = adaptive(light: "#F59E0B", dark: "#FBBF24")
    static let statusAlmostLearned = adaptive(light: "#3B82F6", dark: "#60A5FA")
    static let statusLearned = adaptive(light: "#22C55E", dark: "#4ADE80")

    /// Signalfarbe für falsche Antworten (ersetzt hartcodiertes `Color.red`).
    static let wrong = adaptive(light: "#EF4444", dark: "#F87171")

    // MARK: - Radien

    enum Radius {
        static let card: CGFloat = 22
        static let button: CGFloat = 16
        static let chip: CGFloat = 14
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

    enum Shadow {
        static let color = Color.black.opacity(0.08)
        static let radius: CGFloat = 14
        static let y: CGFloat = 6
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
