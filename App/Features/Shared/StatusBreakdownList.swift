import SwiftUI

/// Status-Aufschlüsselung als Karte: Verteilungsbalken plus eine Zeile je Status
/// (Punkt, Titel, Anzahl). Gemeinsam genutzt von Statistik- und Mastery-Ansicht.
struct StatusBreakdownList: View {
    let counts: [LearningStatus: Int]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            StatusDistributionBar(counts: counts, height: 14)
            ForEach(LearningStatus.allCases) { status in
                HStack {
                    StatusDot(status: status, size: 12)
                    Text(L(status.titleKey)).font(.appBody)
                    Spacer()
                    Text("\(counts[status] ?? 0)")
                        .font(.appBody.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .cardStyle()
    }
}
