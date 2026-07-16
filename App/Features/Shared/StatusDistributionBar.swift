import SwiftUI

/// Horizontaler Balken, der die Verteilung der Status farbig darstellt.
struct StatusDistributionBar: View {
    let counts: [LearningStatus: Int]
    var height: CGFloat = 8

    private var total: Int { counts.values.reduce(0, +) }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(LearningStatus.allCases) { status in
                    let count = counts[status] ?? 0
                    if count > 0 {
                        Rectangle()
                            .fill(status.color)
                            .frame(width: geo.size.width * CGFloat(count) / CGFloat(max(total, 1)))
                    }
                }
            }
        }
        .frame(height: height)
        .background(Theme.surfaceMuted)
        .clipShape(Capsule())
    }
}
