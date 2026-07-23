import SwiftData
import SwiftUI

/// Übersicht aller Badges – freigeschaltete bunt, gesperrte ausgegraut mit
/// Fortschritt. Beim Öffnen wird der Stand einmal ausgewertet (falls z.B. die
/// 100-Wörter-Marke inzwischen erreicht ist), ohne Freischalt-Toast.
struct AchievementsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var vocabs: [Vocab]

    @State private var metrics = AchievementMetrics()
    @State private var unlockedIDs: Set<String> = []

    private var unlockedCount: Int {
        AchievementCatalog.all.filter { unlockedIDs.contains($0.id) }.count
    }

    private let columns = [GridItem(.flexible(), spacing: Theme.Spacing.s),
                           GridItem(.flexible(), spacing: Theme.Spacing.s)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    summaryCard
                    ForEach(Achievement.Category.allCases) { category in
                        categorySection(category)
                    }
                }
                .padding(Theme.Spacing.m)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(L("ach.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("common.done")) { dismiss() }
                }
            }
        }
        .onAppear(perform: refresh)
    }

    /// Aktuellen Stand berechnen und stillschweigend evtl. fällige Badges freischalten.
    private func refresh() {
        AchievementService.evaluate(context: context)
        metrics = AchievementService.metrics(context: context)
        unlockedIDs = AchievementStore.unlockedIDs
    }

    // MARK: - Kopf

    private var summaryCard: some View {
        GradientCard(gradient: Theme.brandGradient, radius: 28, padding: Theme.Spacing.l) {
            VStack(alignment: .leading, spacing: 6) {
                Text("🏆")
                    .font(.system(size: 40))
                Text(L("ach.unlockedCount", unlockedCount, AchievementCatalog.all.count))
                    .font(.appTitle2)
                Text(L("ach.subtitle"))
                    .font(.appSubheadline)
                    .opacity(0.9)
            }
        }
    }

    // MARK: - Kategorie-Abschnitt

    private func categorySection(_ category: Achievement.Category) -> some View {
        let items = AchievementCatalog.all.filter { $0.category == category }
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(L(category.titleKey))
            LazyVGrid(columns: columns, spacing: Theme.Spacing.s) {
                ForEach(items) { achievement in
                    AchievementBadge(achievement: achievement,
                                     metrics: metrics,
                                     unlocked: unlockedIDs.contains(achievement.id),
                                     unlockedOn: AchievementStore.unlockDate(for: achievement.id))
                }
            }
        }
    }
}

/// Eine Badge-Kachel. Freigeschaltet: farbiges Emoji + Freischaltdatum. Gesperrt:
/// blasses Emoji + Fortschritt (Balken/„x / y").
struct AchievementBadge: View {
    let achievement: Achievement
    let metrics: AchievementMetrics
    let unlocked: Bool
    var unlockedOn: Date?

    private var progress: Double { achievement.progress(metrics) }

    var body: some View {
        VStack(spacing: 8) {
            Text(achievement.emoji)
                .font(.system(size: 40))
                .grayscale(unlocked ? 0 : 1)
                .opacity(unlocked ? 1 : 0.45)
            Text(L(achievement.titleKey))
                .font(.appHeadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(unlocked ? .primary : .secondary)
                .lineLimit(2)
            Text(L(achievement.detailKey))
                .font(.appCaption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            footer
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 170, alignment: .top)
        .cardStyle(padding: Theme.Spacing.m)
        .overlay(alignment: .topTrailing) {
            if unlocked {
                Image(systemName: "checkmark.seal.fill")
                    .font(.appSubheadline)
                    .foregroundStyle(LearningStatus.learned.color)
                    .padding(Theme.Spacing.s)
            }
        }
        .opacity(unlocked ? 1 : 0.9)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L(achievement.titleKey))
        .accessibilityValue(unlocked ? L("ach.a11y.unlocked") : L("ach.a11y.locked"))
    }

    @ViewBuilder
    private var footer: some View {
        Spacer(minLength: 0)
        if unlocked {
            if let date = unlockedOn {
                Text(L("ach.unlockedOn", date.formatted(date: .abbreviated, time: .omitted)))
                    .font(.appCaption)
                    .foregroundStyle(.tertiary)
            }
        } else {
            VStack(spacing: 4) {
                ProgressView(value: progress)
                    .tint(Theme.brandStart)
                if let text = achievement.progressText(metrics) {
                    Text(text)
                        .font(.appCaption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
    }
}

#Preview {
    AchievementsView()
        .modelContainer(PersistenceController.preview)
}
