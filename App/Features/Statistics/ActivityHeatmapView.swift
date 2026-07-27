import SwiftUI

/// Kalender-Heatmap (#54) im Stil der GitHub-Contributions: Wochen als Spalten,
/// Wochentage als Zeilen. Die Farbintensität einer Zelle spiegelt die Anzahl der
/// an dem Tag geübten Wörter wider. Quelle sind die Tages-Aggregate aus
/// [[WeeklyReviewStore]]; horizontal scrollbar über mehrere Monate.
struct ActivityHeatmapView: View {
    /// Betrachtungsfenster in Tagen (deckungsgleich mit der Log-Retention).
    var days: Int = 91
    var asOf: Date = .now
    var calendar: Calendar = .current

    private let cellSize: CGFloat = 14
    private let cellSpacing: CGFloat = 3

    private var counts: [Date: Int] {
        WeeklyReviewStore.dailyPracticed(days: days, asOf: asOf)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(alignment: .top, spacing: cellSpacing) {
                weekdayLabels
                grid
            }
            legend
        }
        .cardStyle()
    }

    // MARK: - Raster

    private var rows: [GridItem] {
        Array(repeating: GridItem(.fixed(cellSize), spacing: cellSpacing), count: 7)
    }

    private var grid: some View {
        let cells = makeCells()
        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: rows, spacing: cellSpacing) {
                    ForEach(cells) { cell in
                        cellView(cell)
                            .id(cell.id)
                    }
                }
                .padding(.vertical, 1)
            }
            .onAppear {
                // Auf den aktuellsten Tag (letzte Spalte) scrollen.
                if let last = cells.last { proxy.scrollTo(last.id, anchor: .trailing) }
            }
        }
    }

    @ViewBuilder
    private func cellView(_ cell: DayCell) -> some View {
        if let date = cell.date {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color(forLevel: level(cell.count)))
                .frame(width: cellSize, height: cellSize)
                .accessibilityLabel(accessibilityLabel(for: date, count: cell.count))
        } else {
            Color.clear
                .frame(width: cellSize, height: cellSize)
                .accessibilityHidden(true)
        }
    }

    private var weekdayLabels: some View {
        VStack(spacing: cellSpacing) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                Text(index.isMultiple(of: 2) ? symbol : " ") // nur jede zweite Zeile beschriften
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(height: cellSize)
            }
        }
        .padding(.vertical, 1) // deckungsgleich mit dem Raster-Padding
    }

    // MARK: - Legende

    private var legend: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text(L("stats.heatmap.less"))
                .font(.appCaption)
                .foregroundStyle(.secondary)
            ForEach(0 ... 3, id: \.self) { lvl in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(color(forLevel: lvl))
                    .frame(width: cellSize, height: cellSize)
            }
            Text(L("stats.heatmap.more"))
                .font(.appCaption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Daten / Helfer

    private struct DayCell: Identifiable {
        let id: Int
        let date: Date? // nil = Platzhalter außerhalb des Fensters (Raster bündig halten)
        let count: Int
    }

    /// Baut die spaltenweise (wochenweise) angeordneten Zellen. Der `LazyHGrid`
    /// mit 7 Zeilen füllt spaltenweise von oben – da wir bei einem Wochenanfang
    /// starten, landet jeder Tag automatisch in der richtigen Wochentagszeile.
    private func makeCells() -> [DayCell] {
        let counts = counts // Log einmal laden/decodieren, nicht pro Zelle.
        let end = calendar.startOfDay(for: asOf)
        guard let windowStart = calendar.date(byAdding: .day, value: -(days - 1), to: end) else { return [] }
        let gridStart = calendar.startOfWeek(for: windowStart)
        let lastWeekStart = calendar.startOfWeek(for: end)
        guard let gridEnd = calendar.date(byAdding: .day, value: 6, to: lastWeekStart) else { return [] }

        var cells: [DayCell] = []
        var day = gridStart
        var index = 0
        while day <= gridEnd {
            if day < windowStart || day > end {
                cells.append(DayCell(id: index, date: nil, count: 0))
            } else {
                cells.append(DayCell(id: index, date: day, count: counts[day] ?? 0))
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
            index += 1
        }
        return cells
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    /// Intensitätsstufe: 0 = keine, 1 = 1–2, 2 = 3–5, 3 = 6+ Wörter.
    private func level(_ count: Int) -> Int {
        switch count {
        case ..<1: return 0
        case 1 ... 2: return 1
        case 3 ... 5: return 2
        default: return 3
        }
    }

    private func color(forLevel level: Int) -> Color {
        switch level {
        case 1: return Theme.statusLearned.opacity(0.35)
        case 2: return Theme.statusLearned.opacity(0.65)
        case 3: return Theme.statusLearned
        default: return Theme.surfaceMuted
        }
    }

    private func accessibilityLabel(for date: Date, count: Int) -> String {
        let dateText = date.formatted(.dateTime.day().month(.wide)
            .locale(LocalizationManager.shared.localeForFormatting))
        return L("stats.heatmap.cell", dateText, count)
    }
}
