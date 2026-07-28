import ActivityKit
import SwiftUI
import WidgetKit

/// Live Activity einer laufenden Lernsession: Fortschritt („Wort X von Y" + Balken)
/// auf dem Sperrbildschirm und in der Dynamic Island. Antippen führt über den
/// Deep-Link `dailyhangul://session` zurück in die Session.
struct PracticeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PracticeActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.25))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(DeepLink.sessionURL)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("\(context.state.correct)", systemImage: "checkmark")
                        .foregroundStyle(.green)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Label("\(context.state.wrong)", systemImage: "xmark")
                        .foregroundStyle(.red)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 4) {
                        Text(WidgetStrings.wordProgress(position: context.state.position,
                                                        total: context.state.total))
                            .font(.caption)
                        ProgressView(value: context.state.progress)
                            .tint(.white)
                    }
                }
            } compactLeading: {
                Image(systemName: "graduationcap.fill")
            } compactTrailing: {
                Text("\(context.state.position)/\(context.state.total)")
                    .font(.caption2.monospacedDigit())
            } minimal: {
                Image(systemName: "graduationcap.fill")
            }
            .widgetURL(DeepLink.sessionURL)
        }
    }
}

/// Sperrbildschirm-Darstellung der Session-Live-Activity.
private struct LockScreenView: View {
    let state: PracticeActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(WidgetStrings.sessionTitle, systemImage: "graduationcap.fill")
                    .font(.headline)
                Spacer()
                Label("\(state.correct)", systemImage: "checkmark")
                    .foregroundStyle(.green)
                Label("\(state.wrong)", systemImage: "xmark")
                    .foregroundStyle(.red)
                    .padding(.leading, 4)
            }
            .font(.subheadline)

            Text(WidgetStrings.wordProgress(position: state.position, total: state.total))
                .font(.caption)
                .foregroundStyle(.secondary)

            ProgressView(value: state.progress)
                .tint(.white)
        }
        .padding()
    }
}
