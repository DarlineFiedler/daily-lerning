import SwiftUI

/// Monatskalender für das persönliche Tagesziel: jede Tageszelle ist danach eingefärbt,
/// ob das an dem Tag geltende Tagesziel erreicht (grün), nur teilweise erfüllt oder
/// verpasst wurde. Am rechten Rand einer Woche erscheint ein ⭐, wenn zusätzlich das
/// Wochenziel erreicht wurde. Antippen eines Tages zeigt Ziel & erreichten Wert.
///
/// Modelliert auf [[StreakCalendarView]], speist sich aber aus [[GoalStats]] (Aktivität +
/// Ziel-Historie) statt aus dem Streak-Verlauf.
struct GoalCalendarView: View {
    let stats: GoalStats
    var calendar: Calendar = .current
    var today: Date = .now

    @State private var monthAnchor: Date = .now
    /// Aktuell angetippter Tag für die Detailzeile (`nil` = keiner).
    @State private var selectedDay: Date?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    /// Breite der Stern-Spalte am Wochenende (rechts).
    private let starColumn: CGFloat = 18

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            monthHeader
            weekdayHeader
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                weekRow(week)
            }
            detailLine
            legend
        }
        .cardStyle(padding: Theme.Spacing.l)
    }

    // MARK: - Kopf & Navigation

    private var monthHeader: some View {
        HStack {
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left").font(.appHeadline)
            }
            .accessibilityLabel(L("streak.calendar.prev"))
            Spacer()
            Text(monthTitle)
                .font(.appHeadline)
                .foregroundStyle(.primary)
            Spacer()
            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right").font(.appHeadline)
            }
            .disabled(!canGoForward)
            .accessibilityLabel(L("streak.calendar.next"))
        }
        .foregroundStyle(Theme.brandStart)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 6) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            // Platzhalter unter der Stern-Spalte, damit die Wochentage bündig bleiben.
            Color.clear.frame(width: starColumn)
        }
    }

    // MARK: - Wochenzeile

    private func weekRow(_ week: Week) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(week.days.enumerated()), id: \.offset) { _, day in
                if let day { cell(for: day) } else { Color.clear.frame(height: 34) }
            }
            star(for: week.weekStart)
                .frame(width: starColumn)
        }
    }

    private func cell(for day: Date) -> some View {
        let status = stats.status(on: day, asOf: today)
        let isToday = calendar.isDate(day, inSameDayAs: today)
        let isSelected = selectedDay.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        return Button {
            selectedDay = isSelected ? nil : day
        } label: {
            Text("\(calendar.component(.day, from: day))")
                .font(.appSubheadline.weight(status == .reached ? .bold : .regular))
                .foregroundStyle(foreground(status))
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(background(status))
                .overlay {
                    if isSelected {
                        Circle().strokeBorder(Theme.brandStart, lineWidth: 2)
                    } else if isToday {
                        Circle().strokeBorder(Theme.brandStart, lineWidth: 1.5)
                    }
                }
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: day, status: status))
    }

    @ViewBuilder
    private func star(for weekStart: Date) -> some View {
        if stats.weekReached(weekStarting: weekStart) {
            Image(systemName: "star.fill")
                .font(.system(size: 12))
                .foregroundStyle(Theme.statusLearned)
                .accessibilityLabel(L("goalstats.calendar.legend.star"))
        } else {
            Color.clear.accessibilityHidden(true)
        }
    }

    // MARK: - Detailzeile

    @ViewBuilder
    private var detailLine: some View {
        if let day = selectedDay {
            let target = stats.dailyTarget(on: day)
            let value = stats.value(on: day)
            Text(detailText(for: day, target: target, value: value))
                .font(.appCaption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity)
        }
    }

    private func detailText(for day: Date, target: Int, value: Int) -> String {
        let dateText = day.formatted(.dateTime.weekday(.abbreviated).day().month()
            .locale(LocalizationManager.shared.localeForFormatting))
        return target > 0
            ? L("goalstats.calendar.detail", dateText, value, target)
            : L("goalstats.calendar.detail.noGoal", dateText, value)
    }

    // MARK: - Legende

    private var legend: some View {
        HStack(spacing: Theme.Spacing.m) {
            legendItem(color: Theme.statusLearned, label: L("goalstats.calendar.legend.reached"))
            legendItem(color: Theme.brandStart.opacity(0.25), label: L("goalstats.calendar.legend.partial"))
            legendItem(color: Theme.wrong.opacity(0.35), label: L("goalstats.calendar.legend.missed"))
            starLegend
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label).font(.appCaption).foregroundStyle(.secondary)
        }
    }

    private var starLegend: some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
                .font(.system(size: 10))
                .foregroundStyle(Theme.statusLearned)
            Text(L("goalstats.calendar.legend.star")).font(.appCaption).foregroundStyle(.secondary)
        }
    }

    // MARK: - Darstellung des Status

    private func foreground(_ status: GoalStats.DayStatus) -> Color {
        switch status {
        case .reached: return .white
        case .partial: return .primary
        case .missed: return Theme.wrong
        case .noGoal, .upcoming: return .secondary
        }
    }

    @ViewBuilder
    private func background(_ status: GoalStats.DayStatus) -> some View {
        switch status {
        case .reached: Theme.statusLearned
        case .partial: Theme.brandStart.opacity(0.18)
        case .missed: Theme.wrong.opacity(0.12)
        case .noGoal, .upcoming: Color.clear
        }
    }

    // MARK: - Wochen-/Tagesberechnung

    private struct Week {
        let weekStart: Date
        let days: [Date?] // 7 Einträge; nil = Tag außerhalb des angezeigten Monats
    }

    /// Volle Kalenderwochen, die den angezeigten Monat abdecken (jede Zeile beginnt am
    /// `firstWeekday`). Tage außerhalb des Monats sind `nil` (leere Zellen).
    private var weeks: [Week] {
        guard let interval = calendar.dateInterval(of: .month, for: monthAnchor) else { return [] }
        let firstOfMonth = interval.start
        let month = calendar.component(.month, from: firstOfMonth)
        let gridStart = calendar.startOfWeek(for: firstOfMonth)
        let lastOfMonth = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? firstOfMonth
        let lastWeekStart = calendar.startOfWeek(for: lastOfMonth)

        var result: [Week] = []
        var weekStart = gridStart
        while weekStart <= lastWeekStart {
            let days: [Date?] = (0 ..< 7).map { offset in
                guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
                return calendar.component(.month, from: date) == month ? date : nil
            }
            result.append(Week(weekStart: weekStart, days: days))
            guard let next = calendar.date(byAdding: .day, value: 7, to: weekStart) else { break }
            weekStart = next
        }
        return result
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    private var monthTitle: String {
        monthAnchor.formatted(.dateTime.month(.wide).year()
            .locale(LocalizationManager.shared.localeForFormatting))
    }

    private var canGoForward: Bool {
        let displayed = calendar.dateInterval(of: .month, for: monthAnchor)?.start
        let currentMonth = calendar.dateInterval(of: .month, for: today)?.start
        guard let displayed, let currentMonth else { return false }
        return displayed < currentMonth
    }

    private func shiftMonth(_ value: Int) {
        if let next = calendar.date(byAdding: .month, value: value, to: monthAnchor) {
            monthAnchor = next
            selectedDay = nil
        }
    }

    private func accessibilityLabel(for day: Date, status: GoalStats.DayStatus) -> String {
        let date = day.formatted(.dateTime.day().month(.wide)
            .locale(LocalizationManager.shared.localeForFormatting))
        let key: String
        switch status {
        case .reached: key = "goalstats.calendar.legend.reached"
        case .partial: key = "goalstats.calendar.legend.partial"
        case .missed: key = "goalstats.calendar.legend.missed"
        case .noGoal, .upcoming: return date
        }
        return "\(date): \(L(key))"
    }
}
