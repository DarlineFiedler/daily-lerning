import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Farb-Helfer für das bunte Design: Aufhellen/Abdunkeln und Verläufe aus einer
/// einzelnen (Gruppen-)Farbe. Baut auf `Color(hex:)` (Shared/Color+Hex.swift) auf.
extension Color {

    /// Hellt eine Farbe um `amount` (0…1) auf.
    func lightened(_ amount: CGFloat = 0.2) -> Color {
        adjust(brightness: amount, saturation: -amount * 0.3)
    }

    /// Dunkelt eine Farbe um `amount` (0…1) ab.
    func darkened(_ amount: CGFloat = 0.2) -> Color {
        adjust(brightness: -amount, saturation: 0)
    }

    private func adjust(brightness: CGFloat, saturation: CGFloat) -> Color {
        #if canImport(UIKit)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return self }
        return Color(
            hue: Double(h),
            saturation: Double(min(max(s + saturation, 0), 1)),
            brightness: Double(min(max(b + brightness, 0), 1)),
            opacity: Double(a)
        )
        #else
        return self
        #endif
    }

    /// Ein diagonaler 2-Stopp-Verlauf, der aus dieser Farbe entsteht.
    var vibrantGradient: LinearGradient {
        LinearGradient(
            colors: [lightened(0.14), darkened(0.12)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension LinearGradient {
    /// Verlauf aus einem Hex-String einer Gruppenfarbe.
    static func forHex(_ hex: String) -> LinearGradient {
        Color(hex: hex).vibrantGradient
    }
}
