import SwiftUI

/// Einstieg zu den Problemwörtern im Home-Fortschritt: rendert nur etwas, wenn es aktuell
/// welche gibt (`count > 0`; selbstheilend, siehe [[Vocab]] `isProblemWord`). Führt in die
/// gefilterte Wörter-Liste (`WordListView(problemsOnly:)`). Als eigene View ausgelagert,
/// damit `HomeView` schlank bleibt und die Sichtbarkeit hier gekapselt ist.
struct ProblemWordsCard: View {
    let count: Int

    var body: some View {
        if count > 0 {
            NavigationLink {
                WordListView(titleKey: "practice.problems.title", problemsOnly: true)
            } label: {
                HStack(spacing: Theme.Spacing.s) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.wrong)
                    Text(L("home.problemWords", count))
                        .font(.appSubheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
                .padding(Theme.Spacing.m)
                .background(Theme.wrong.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, Theme.Spacing.xs)
        }
    }
}
