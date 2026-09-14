import SwiftUI

// Wiederverwendbare Bausteine der „Papier & Tinte"-Optik: Papierhintergrund mit
// feiner Linierung, harte Offset-Schatten ohne Blur (Print-Look), Papierkarten,
// Gruppen-Akzentbalken und handschriftliche Randnotizen.

// MARK: - Harter Offset-Schatten (kein Blur)

extension View {
    /// Print-Schatten: fester Versatz, **kein** Weichzeichnen. Standard entspricht dem
    /// ruhigen Karten-Schatten der Vorlage (`2px 3px 0`, ~9 % Tinte).
    func hardShadow(x: CGFloat = 2, y: CGFloat = 3, color: Color = Color(hex: "#211E19").opacity(0.09)) -> some View {
        shadow(color: color, radius: 0, x: x, y: y)
    }

    /// Kräftiger Button-Schatten in der dunklen Variante der Füllfarbe (`0 4px 0`).
    func buttonHardShadow(_ color: Color, y: CGFloat = 4) -> some View {
        shadow(color: color, radius: 0, x: 0, y: y)
    }
}

// MARK: - Papierhintergrund mit Linienraster

/// Feine, waagerechte Papier-Linierung (1pt Linie alle 4pt), sehr dezent (~2,2 % Tinte).
struct PaperTexture: View {
    var body: some View {
        Canvas { context, size in
            let line = Color(hex: "#211E19").opacity(0.022)
            var y: CGFloat = 0
            while y < size.height {
                context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(line))
                y += 4
            }
        }
        .allowsHitTesting(false)
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
