import SwiftUI

/// Kompaktes, versal gesetztes Monospace-Label über einem Abschnitt (Papier-Optik:
/// Courier Prime, weit gesperrt, gedämpfte Tinte). Das mono-Pendant zur serifen
/// `SectionHeader` – gedacht für dichte Konfigurationslisten wie „Runde vorbereiten"
/// (Design-Handoff 2a), wo die serifen Überschriften zu wuchtig wären.
struct SectionLabel: View {
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.appMono(10))
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(Theme.inkMuted)
    }
}
