import SwiftUI

/// Kachel mit großer Zahl + Beschriftung (für Home & Statistik).
struct StatTile: View {
    let value: String
    let label: String
    var systemImage: String?
    var tint: Color = Theme.brandStart

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.appHeadline)
                    .foregroundStyle(tint)
            }
            Text(value)
                .font(.appDisplay(30))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
            Text(label)
                .font(.appCaption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}
