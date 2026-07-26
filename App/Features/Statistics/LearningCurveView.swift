import Charts
import SwiftUI

/// Lernkurve (#40): zeitlicher Verlauf des Lernfortschritts über die letzten
/// Wochen – geübte und neu gelernte Wörter pro Woche sowie die Trefferquote.
/// Quelle ist der Wochen-Aktivitäts-Log ([[WeeklyReviewStore]]); rein global,
/// da der Log nicht nach Gruppe aufgeschlüsselt ist.
struct LearningCurveView: View {
    /// Betrachtungsfenster in Wochen (deckungsgleich mit der Log-Retention).
    var weeks: Int = 12
    var asOf: Date = .now

    private var buckets: [WeekBucket] {
        WeeklyReviewStore.weeklySeries(weeks: weeks, asOf: asOf)
    }

    /// Wochen mit beantworteten Antworten – Basis für den Trefferquoten-Chart.
    private var accuracyPoints: [WeekBucket] {
        buckets.filter { $0.accuracy != nil }
    }

    private var hasAnyActivity: Bool {
        buckets.contains { $0.hasActivity }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            if hasAnyActivity {
                legend
                volumeChart
                if !accuracyPoints.isEmpty {
                    accuracySection
                }
            } else {
                emptyHint
            }
        }
        .cardStyle()
    }

    // MARK: - Geübte / neu gelernte Wörter

    private var volumeChart: some View {
        Chart(buckets, id: \.weekStart) { bucket in
            BarMark(
                x: .value(L("stats.trend.week"), bucket.weekStart, unit: .weekOfYear),
                y: .value(L("stats.trend.practiced"), bucket.practiced)
            )
            .foregroundStyle(Theme.brandStart.gradient)
            .cornerRadius(4)

            LineMark(
                x: .value(L("stats.trend.week"), bucket.weekStart, unit: .weekOfYear),
                y: .value(L("stats.trend.learned"), bucket.newlyLearned)
            )
            .foregroundStyle(Theme.statusLearned)
            .lineStyle(StrokeStyle(lineWidth: 2))
            .interpolationMethod(.catmullRom)
            .symbol {
                Circle().fill(Theme.statusLearned).frame(width: 6, height: 6)
            }
        }
        .chartYAxis { AxisMarks(position: .leading) }
        .chartXAxis { weekAxis }
        .frame(height: 180)
        .accessibilityLabel(L("stats.trend.title"))
    }

    // MARK: - Trefferquote

    private var accuracySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(L("stats.trend.accuracy"))
                .font(.appCaption.weight(.semibold))
                .foregroundStyle(.secondary)
            Chart(accuracyPoints, id: \.weekStart) { bucket in
                LineMark(
                    x: .value(L("stats.trend.week"), bucket.weekStart, unit: .weekOfYear),
                    y: .value(L("stats.trend.accuracy"), bucket.accuracy ?? 0)
                )
                .foregroundStyle(Theme.brandEnd)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
                .symbol {
                    Circle().fill(Theme.brandEnd).frame(width: 6, height: 6)
                }
            }
            .chartYScale(domain: 0 ... 100)
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let percent = value.as(Int.self) { Text("\(percent)%") }
                    }
                }
            }
            .chartXAxis { weekAxis }
            .frame(height: 110)
            .accessibilityLabel(L("stats.trend.accuracy"))
        }
    }

    // MARK: - Achse / Legende / Leerzustand

    private var weekAxis: some AxisContent {
        AxisMarks(values: .stride(by: .weekOfYear, count: 4)) { value in
            AxisGridLine()
            AxisTick()
            AxisValueLabel {
                if let date = value.as(Date.self) {
                    Text(date.formatted(.dateTime.month(.abbreviated).day()
                            .locale(LocalizationManager.shared.localeForFormatting)))
                }
            }
        }
    }

    private var legend: some View {
        HStack(spacing: Theme.Spacing.m) {
            legendItem(color: Theme.brandStart, label: L("stats.trend.practiced"))
            legendItem(color: Theme.statusLearned, label: L("stats.trend.learned"))
            Spacer(minLength: 0)
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .font(.appCaption)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyHint: some View {
        Text(L("stats.trend.empty"))
            .font(.appCaption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, Theme.Spacing.l)
    }
}
