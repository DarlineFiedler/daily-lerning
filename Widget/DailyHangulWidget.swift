import SwiftUI
import WidgetKit

/// Lock-Screen-Widget (accessoryRectangular) + kleines Home-Screen-Widget.
struct DailyHangulWidget: Widget {
    let kind = WidgetKind.vocab

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VocabTimelineProvider()) { entry in
            VocabWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("DailyHangul")
        .description(WidgetStrings.empty) // Kurzbeschreibung im Widget-Katalog
        .supportedFamilies([
            .accessoryRectangular,
            .accessoryInline,
            .systemSmall
        ])
    }
}

/// Zweiter Home-Screen-Widget-Kind: Streak-Serie + Fortschrittsring gegen das
/// persönliche Ziel. Bewusst ein eigenständiger Kind (statt einer konfigurierbaren
/// Variante des Wort-Widgets), damit das bestehende Wort-Widget unangetastet bleibt.
struct StreakWidget: Widget {
    let kind = WidgetKind.streak

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakTimelineProvider()) { entry in
            StreakWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(WidgetStrings.streakDisplayName)
        .description(WidgetStrings.streakDescription)
        .supportedFamilies([.systemSmall])
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
            Text(entry.settings.showMeaning ? "\(word.word) – \(word.meaning)" : word.word)

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(word.word)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                secondaryLine(for: word)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .minimumScaleFactor(0.7)
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
                resultControls(for: word)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Interaktive „Gewusst"/„Nochmal"-Steuerung des systemSmall-Widgets (iOS 17). Nach dem
    /// Tippen zeigt dieselbe Karte kurz „Verbucht ✓" statt der Buttons – der Provider markiert
    /// dafür den aktuellen Slot (siehe [[VocabTimelineProvider]]). Bewusst nur hier und nicht
    /// in den `accessory`-Familien: Lock-Screen-Widgets unterstützen keine interaktiven Buttons.
    @ViewBuilder
    private func resultControls(for word: WidgetWord) -> some View {
        if let correct = entry.justAnsweredCorrect {
            Label(WidgetStrings.logged, systemImage: correct ? "checkmark.circle.fill" : "arrow.counterclockwise.circle.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        } else {
            HStack(spacing: 6) {
                Button(intent: RegisterWidgetResultIntent(wordID: word.id, correct: true)) {
                    Label(WidgetStrings.knewIt, systemImage: "checkmark")
                }
                Button(intent: RegisterWidgetResultIntent(wordID: word.id, correct: false)) {
                    Label(WidgetStrings.again, systemImage: "arrow.counterclockwise")
                }
            }
            .font(.caption2.weight(.semibold))
            .labelStyle(.titleOnly)
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .tint(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
    }

    @ViewBuilder
    private func secondaryLine(for word: WidgetWord) -> some View {
        if entry.settings.showMeaning {
            Text(word.meaning)
        } else {
            EmptyView()
        }
    }

    private var emptyView: some View {
        Label(WidgetStrings.empty, systemImage: "book.closed")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
