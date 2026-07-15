import WidgetKit
import SwiftUI

/// Lock-Screen-Widget (accessoryRectangular) + kleines Home-Screen-Widget.
struct DailyHangulWidget: Widget {
    let kind = "DailyHangulWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VocabTimelineProvider()) { entry in
            VocabWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("DailyHangul")
        .description(WidgetStrings.empty)   // Kurzbeschreibung im Widget-Katalog
        .supportedFamilies([
            .accessoryRectangular,
            .accessoryInline,
            .systemSmall
        ])
    }
}

struct VocabWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: VocabEntry

    var body: some View {
        if let word = entry.word {
            content(for: word)
                .widgetURL(DeepLink.wordURL(id: word.id))
        } else {
            emptyView
        }
    }

    @ViewBuilder
    private func content(for word: WidgetWord) -> some View {
        switch family {
        case .accessoryInline:
            Text(showMeaningInline ? "\(word.word) – \(word.meaning)" : word.word)

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(word.word)
                    .font(.headline)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                secondaryLine(for: word)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        default: // systemSmall
            VStack(spacing: 6) {
                Text(word.word)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                secondaryLine(for: word)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func secondaryLine(for word: WidgetWord) -> some View {
        if entry.settings.showMeaningOnTap {
            Text(WidgetStrings.tapHint)
        } else if entry.settings.showMeaning {
            Text(word.meaning)
        } else {
            EmptyView()
        }
    }

    private var showMeaningInline: Bool {
        entry.settings.showMeaning && !entry.settings.showMeaningOnTap
    }

    private var emptyView: some View {
        Label(WidgetStrings.empty, systemImage: "book.closed")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
