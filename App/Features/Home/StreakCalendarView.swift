import SwiftUI

/// Monatskalender, der markiert, an welchen Tagen gelernt wurde (grün), welche
/// Tage per Joker gerettet wurden (blau) und welche verpasst wurden (rot).
struct StreakCalendarView: View {
    private let activeDays: Set<Date>
    private let jokerDays: Set<Date>
    /// Ältester verfolgter Tag – vorab berechnet, statt pro Zelle neu zu ermitteln.
    private let firstTrackedDay: Date?
    private let calendar: Calendar
    private let today: Date

    @State private var monthAnchor: Date

    init(activeDays: [Date], jokerUses: [Date], calendar: Calendar = .current, today: Date = .now) {
        self.calendar = calendar
        self.today = today
        let active = Set(activeDays.map { calendar.startOfDay(for: $0) })
        let joker = Set(jokerUses.map { calendar.startOfDay(for: $0) })
        self.activeDays = active
        jokerDays = joker
        firstTrackedDay = active.union(joker).min()
        _monthAnchor = State(initialValue: today)
    }

    private enum DayStatus { case learned, joker, missed, today, upcoming }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            monthHeader
            weekdayHeader
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, day in
                    if let day { cell(for: day) } else { Color.clear.frame(height: 34) }
                }
            }
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
        }
    }

    private func cell(for day: Date) -> some View {
        let status = status(for: day)
        return Text("\(calendar.component(.day, from: day))")
            .font(.appSubheadline.weight(status == .learned || status == .joker ? .bold : .regular))
            .foregroundStyle(foreground(status))
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(background(status))
            .overlay {
                if status == .today {
                    Circle().strokeBorder(Theme.brandStart, lineWidth: 1.5)
                }
            }
            .clipShape(Circle())
            .accessibilityLabel(accessibilityLabel(for: day, status: status))
    }

    private var legend: some View {
        HStack(spacing: Theme.Spacing.m) {
            legendItem(color: Theme.statusLearned, label: L("streak.calendar.legend.learned"))
            legendItem(color: Theme.statusAlmostLearned, label: L("streak.calendar.legend.joker"))
            legendItem(color: Theme.wrong, label: L("streak.calendar.legend.missed"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label).font(.appCaption).foregroundStyle(.secondary)
        }
    }

    // MARK: - Status & Darstellung

    private func status(for day: Date) -> DayStatus {
        let d = calendar.startOfDay(for: day)
        let start = calendar.startOfDay(for: today)
        if activeDays.contains(d) { return .learned }
        if jokerDays.contains(d) { return .joker }
        if d == start { return .today }
        if d > start { return .upcoming }
        if let first = firstTrackedDay, d >= first { return .missed }
        return .upcoming
    }

    private func foreground(_ status: DayStatus) -> Color {
        switch status {
        case .learned, .joker: return .white
        case .missed: return Theme.wrong
        case .today: return .primary
        case .upcoming: return .secondary
        }
    }

    @ViewBuilder
    private func background(_ status: DayStatus) -> some View {
        switch status {
        case .learned: Theme.statusLearned
        case .joker: Theme.statusAlmostLearned
        case .missed: Theme.wrong.opacity(0.12)
        case .today, .upcoming: Color.clear
        }
    }

    // MARK: - Berechnungen

    /// Tage des angezeigten Monats, mit führenden `nil`-Platzhaltern bis zum
    /// ersten Wochentag (respektiert `firstWeekday`).
    private var monthDays: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: monthAnchor) else { return [] }
        let firstOfMonth = interval.start
        let dayCount = calendar.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 0
        let weekday = calendar.component(.weekday, from: firstOfMonth)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0 ..< dayCount {
            cells.append(calendar.date(byAdding: .day, value: offset, to: firstOfMonth))
        }
        return cells
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
        }
    }

    private func accessibilityLabel(for day: Date, status: DayStatus) -> String {
        let date = day.formatted(.dateTime.day().month(.wide)
            .locale(LocalizationManager.shared.localeForFormatting))
        let key: String
        switch status {
        case .learned: key = "streak.calendar.legend.learned"
        case .joker: key = "streak.calendar.legend.joker"
        case .missed: key = "streak.calendar.legend.missed"
        case .today, .upcoming: return date
        }
        return "\(date): \(L(key))"
    }
}

#Preview {
    let cal = Calendar.current
    let day: (Int) -> Date = { cal.date(byAdding: .day, value: -$0, to: .now)! }
    return StreakCalendarView(
        activeDays: [day(0), day(1), day(2), day(4), day(5)],
        jokerUses: [day(3)]
    )
    .padding()
}
