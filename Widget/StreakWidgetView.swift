import SwiftUI
import WidgetKit

/// `.systemSmall`-Ansicht des Streak-Widgets: Flamme + Streak-Zahl und – falls ein
/// Ziel gesetzt ist – ein Fortschrittsring gegen das Tages-/Wochenziel. Ohne Ziel
/// bleibt es eine reine Streak-Anzeige (Fallback), inkl. „längste Serie".
struct StreakWidgetView: View {
    let entry: StreakEntry

    private var model: StreakWidgetModel { entry.model }
    private var hasStreak: Bool { model.streak > 0 }

    var body: some View {
        VStack(spacing: 6) {
            streakHeadline
            subtitle
            Spacer(minLength: 0)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(DeepLink.streakURL)
    }

    // MARK: - Streak-Kopf (Flamme + Zahl)

    private var streakHeadline: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 26))
                .foregroundStyle(hasStreak ? flameGradient : AnyShapeStyle(.secondary))
            Text("\(model.streak)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var subtitle: some View {
        Text(hasStreak ? WidgetStrings.streakDays(model.streak) : WidgetStrings.noStreak)
            .font(.caption)
            .foregroundStyle(.secondary)
            .minimumScaleFactor(0.7)
            .lineLimit(1)
    }

    // MARK: - Fuß: Ziel-Ring oder längste Serie

    @ViewBuilder
    private var footer: some View {
        if let goal = model.goal {
            goalRow(goal)
        } else if model.longest > 0 {
            Text(WidgetStrings.longestStreak(model.longest))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }

    private func goalRow(_ goal: StreakWidgetModel.GoalProgress) -> some View {
        HStack(spacing: 8) {
            ProgressRing(fraction: goal.fraction, reached: goal.reached)
                .frame(width: 38, height: 38)
                .overlay {
                    if goal.reached {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.green)
                    }
                }
            VStack(alignment: .leading, spacing: 1) {
                Text(WidgetStrings.goalLabel(isDaily: goal.isDaily))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(goal.done)/\(goal.target)")
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Spacer(minLength: 0)
        }
    }

    private var flameGradient: AnyShapeStyle {
        AnyShapeStyle(LinearGradient(colors: [.orange, .red],
                                     startPoint: .top, endPoint: .bottom))
    }
}

/// Schlanker Fortschrittsring für das Streak-Widget. Bei Zielerreichung wechselt
/// die Füllung auf Grün.
struct ProgressRing: View {
    let fraction: Double
    let reached: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.25), lineWidth: 6)
            Circle()
                // Mindestlänge, damit auch 0 % ein sichtbarer Punkt bleibt.
                .trim(from: 0, to: max(0.02, fraction))
                .stroke(reached ? Color.green : Color.orange,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}
