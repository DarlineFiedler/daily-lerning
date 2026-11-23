import SwiftUI
import UIKit

// Wiederverwendbare Bausteine der „Papier & Tinte"-Optik: Papierhintergrund mit
// feiner Linierung, harte Offset-Schatten ohne Blur (Print-Look), Papierkarten,
// Gruppen-Akzentbalken und handschriftliche Randnotizen.

// MARK: - Harter Offset-Schatten (kein Blur)

extension View {
    /// Print-Schatten: fester Versatz, **kein** Weichzeichnen. Standard entspricht dem
    /// ruhigen Karten-Schatten der Vorlage (`2px 3px 0`, ~9 % Tinte). Default nutzt das
    /// gecachte `Theme.Shadow.color`-Token (identischer Wert), damit `Color(hex:)` nicht an
    /// jeder Aufrufstelle neu geparst wird.
    func hardShadow(x: CGFloat = 2, y: CGFloat = 3, color: Color = Theme.Shadow.color) -> some View {
        shadow(color: color, radius: 0, x: x, y: y)
    }

    /// Kräftiger Button-Schatten in der dunklen Variante der Füllfarbe (`0 4px 0`).
    func buttonHardShadow(_ color: Color, y: CGFloat = 4) -> some View {
        shadow(color: color, radius: 0, x: 0, y: y)
    }
}

// MARK: - Papierhintergrund mit Linienraster

/// Feine, waagerechte Papier-Linierung (1pt Linie alle 4pt), sehr dezent (~2,2 % Tinte).
///
/// Statt pro Canvas-Pass ~N/4 Linien-Rects über die volle Höhe zu füllen (der Hintergrund
/// liegt via `paperBackground()` auf ~24 Screens), wird die Linierung **einmal** als
/// 64×4pt-Kachel gerendert und vom System gekachelt – konstante Kosten je Render statt
/// hunderter Draw-Ops. Die Kachel ist bewusst breit (statt 1pt), damit ein Vollbild nur
/// ~7 statt ~430 Kacheln pro Zeile braucht; Speicher kostet das kaum (~9 KB @3x).
struct PaperTexture: View {
    /// Tintenfarbe der Linien (`#211E19` @ 2,2 %). Aus dem gemeinsamen Hex-Parser
    /// ([[HexColorComponents]]) gebaut, damit sie nicht gegenüber `Color(hex:)` driftet.
    static let lineColor: UIColor = {
        let c = HexColorComponents.parse("#211E19")
            ?? HexColorComponents.RGBA(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        return UIColor(red: c.red, green: c.green, blue: c.blue, alpha: 0.022)
    }()

    /// Kachelgröße in Punkten: 1pt Linie + 3pt Lücke hoch, breit genug für wenige Kacheln.
    static let tileSize = CGSize(width: 64, height: 4)

    /// Einmal gerenderte, kachelbare Linien-Textur (siehe `makeTile()`).
    static let tile: UIImage = makeTile()

    /// Rendert die 64×4pt-Kachel: oberste 1pt in `lineColor`, darunter 3pt transparent –
    /// gekachelt ergibt das dieselbe Linierung (1pt Linie alle 4pt) wie zuvor.
    static func makeTile() -> UIImage {
        let format = UIGraphicsImageRendererFormat.preferred()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: tileSize, format: format)
        return renderer.image { ctx in
            lineColor.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: tileSize.width, height: 1))
        }
    }

    var body: some View {
        Image(uiImage: Self.tile)
            // Kein Glätten beim Umrechnen auf eine andere Display-Skalierung (externes
            // Display, iPad/Mac): die 1pt-Linie bleibt hart statt auf zwei Zeilen zu verschmieren.
            .interpolation(.none)
            .resizable(resizingMode: .tile)
            .allowsHitTesting(false)
            // Rein dekorativ: wie das frühere `Canvas` nicht im Accessibility-Baum auftauchen
            // (sonst verschiebt das Hintergrund-`Image` die A11y-Struktur der Screens, was die
            // identifier-basierten UI-Tests stört).
            .accessibilityHidden(true)
    }
}

private struct PaperBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                Theme.paper
                    .overlay(PaperTexture())
                    .ignoresSafeArea()
            )
    }
}

extension View {
    /// Setzt den warmen Papier-Hintergrund inkl. Linienraster hinter den Inhalt.
    func paperBackground() -> some View { modifier(PaperBackgroundModifier()) }
}

// MARK: - Papierkarte (4pt Radius, Haarlinien-Rahmen, harter Schatten)

struct PaperCard: ViewModifier {
    var padding: CGFloat = 16
    var fill: Color = Theme.card
    var radius: CGFloat = Theme.Radius.card

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
            .hardShadow()
    }
}

extension View {
    /// Papierkarte: Kartenfläche, 1px Haarlinien-Rahmen, 4pt Radius, harter Schatten.
    func paperCard(padding: CGFloat = 16, fill: Color = Theme.card, radius: CGFloat = Theme.Radius.card) -> some View {
        modifier(PaperCard(padding: padding, fill: fill, radius: radius))
    }
}

// MARK: - Gruppen-Akzentbalken (4px linker Balken in Gruppenfarbe)

private struct GroupAccentModifier: ViewModifier {
    let color: Color
    var radius: CGFloat = Theme.Radius.card

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(color)
                    .frame(width: 4)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: radius,
                            bottomLeadingRadius: radius,
                            style: .continuous
                        )
                    )
            }
    }
}

extension View {
    /// Legt einen 4px breiten Farbbalken (Gruppenfarbe) an die linke Kante.
    func groupAccent(_ color: Color, radius: CGFloat = Theme.Radius.card) -> some View {
        modifier(GroupAccentModifier(color: color, radius: radius))
    }
}

// MARK: - Handschriftliche Randnotiz

/// Kleine handschriftliche Notiz (Nanum Pen), leicht rotiert – die Stil-Signatur der App.
struct HandNote: View {
    let text: String
    var size: CGFloat = 19
    var color: Color = Theme.vermillion
    var angle: Double = -2

    init(_ text: String, size: CGFloat = 19, color: Color = Theme.vermillion, angle: Double = -2) {
        self.text = text
        self.size = size
        self.color = color
        self.angle = angle
    }

    var body: some View {
        Text(text)
            .font(.appHand(size))
            .foregroundStyle(color)
            .rotationEffect(.degrees(angle))
    }
}

// MARK: - Pflanzenreihe (jedes Wort eine Pflanze)

/// Emoji-Reihe der Wörter einer Gruppe: jede Pflanze zeigt die Lernstufe (SRS).
/// Einzeilig mit Abschneiden, damit die Reihe kompakt bleibt (Screens 1a/1d/1e).
struct PlantRow: View {
    let group: VocabGroup
    var limit: Int = 16
    var size: CGFloat = 21

    var body: some View {
        let plants = group.vocabs
            .sorted { $0.createdAt < $1.createdAt }
            .prefix(limit)
            .map { VocabGarden.plantEmoji(for: $0.status, groupHex: group.colorHex) }
            .joined()
        Text(plants.isEmpty ? "🌱" : plants)
            .font(.system(size: size))
            .lineLimit(1)
            .truncationMode(.tail)
    }
}

// MARK: - Mono-Label (Großbuchstaben, gesperrt)

extension View {
    /// Typischer Mono-Label-Stil: gesperrt + Großbuchstaben-Optik + gedämpfte Tinte.
    func monoLabel(_ tracking: CGFloat = 1) -> some View {
        self.font(.appCaption)
            .tracking(tracking)
            .textCase(.uppercase)
            .foregroundStyle(Theme.inkMuted)
    }
}
