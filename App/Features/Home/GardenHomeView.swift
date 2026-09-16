import SwiftData
import SwiftUI

/// **Screen 1a — Start · Mein Garten** (v3-Redesign).
/// Startseite als Gartentagebuch: Datum + Titel, Streak-Kreis, „Heute gießen"-Karte
/// (fällige Wörter), und die Gartenkarte mit den Gruppen als Beeten – jedes Wort eine
/// Pflanze, deren Emoji die Lernstufe (SRS) zeigt. Nutzt ausschließlich vorhandene
/// Daten/Stores (`DailyPlan`, `StreakStore`, `VocabGarden`, `VocabGroup`).
struct GardenHomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Vocab.createdAt) private var vocabs: [Vocab]
    @Query(sort: \VocabGroup.sortOrder) private var groups: [VocabGroup]

    @State private var showReview = false
    @State private var showStreakDetail = false
    @State private var showNewGroup = false
    @State private var showGoalStats = false

    // Persönliches Ziel (geteilter Store, wie im Home-Dashboard).
    @AppStorage(GoalKeys.metric, store: AppGroup.defaults) private var goalMetricRaw = GoalMetric.practiced.rawValue
    @AppStorage(GoalKeys.weekly, store: AppGroup.defaults) private var weeklyGoal = GoalOptions.defaultWeekly
    @AppStorage(GoalKeys.daily, store: AppGroup.defaults) private var dailyGoal = GoalOptions.defaultDaily

    private var activeVocabs: [Vocab] { vocabs.filter { $0.group?.isArchived != true } }
    private var activeGroups: [VocabGroup] { groups.filter { !$0.isArchived } }

    private var goalMetric: GoalMetric { GoalMetric(rawValue: goalMetricRaw) ?? .practiced }
    private var dayDone: Int { WeeklyReviewStore.dayProgress(for: goalMetric) }
    private var weekDone: Int { WeeklyReviewStore.weekProgress(for: goalMetric) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    waterCard
                    if activeGroups.isEmpty {
                        emptyGarden
                    } else {
                        challengeCard
                        gardenCard
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                // Genug Luft unten, damit die letzte Sektion (Wochenrückblick) über der
                // schwebenden Üben-FAB/Tab-Leiste sichtbar bleibt und nicht zurückfedert.
                .padding(.bottom, 88)
            }
            .paperBackground()
            .navigationBarHidden(true)
            .onAppear {
                StreakStore.settle()
                GoalHistoryStore.snapshotToday()
            }
            .sheet(isPresented: $showReview) { ReviewSessionView() }
            .sheet(isPresented: $showNewGroup) { GroupEditView(group: nil) }
            .sheet(isPresented: $showGoalStats) { GoalStatsView() }
            .sheet(isPresented: $showStreakDetail) {
                StreakDetailView(streak: StreakStore.displayStreak(), longest: StreakStore.longest,
                                 jokers: StreakStore.availableJokers(), maxJokers: StreakStore.maxJokers,
                                 jokerUses: StreakStore.jokerUses, activeDays: StreakStore.activeDays)
            }
        }
    }

    // MARK: - Kopf (Datum + Titel + Streak-Notiz + Ziel-Ring)

    private var header: some View {
        let streak = StreakStore.displayStreak()
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(dateText)
                    .font(.appMono(13))
                    .foregroundStyle(Theme.inkSecondary)
                Text(L("garden.title"))
                    .font(.appDisplay(30))
                    .foregroundStyle(Theme.ink)
                if streak > 0 {
                    HandNote(L("garden.streak.note", streak), size: 17)
                        .padding(.top, 2)
                }
            }
            Spacer()
            // Ist ein Tagesziel gesetzt, zeigt der Kreis den heutigen Ziel-Fortschritt;
            // sonst fällt er auf den Streak-Kreis zurück.
            if dailyGoal > 0 { goalRing(streak: streak) } else { streakCircle(streak) }
        }
        .padding(.horizontal, 6)
        .padding(.top, 4)
    }

    /// Tagesziel-Ring: gefüllter Bogen = heute erreichter Anteil, innen „erledigt/Ziel".
    private func goalRing(streak: Int) -> some View {
        let target = max(dailyGoal, 1)
        let fraction = min(1, Double(dayDone) / Double(target))
        return Button { showGoalStats = true } label: {
            ZStack {
                Circle().stroke(Theme.ink.opacity(0.10), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(Theme.leaf, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 1) {
                    Text("\(dayDone)").font(.appDisplay(19)).foregroundColor(Theme.ink)
                        + Text("/\(dailyGoal)").font(.appMono(11)).foregroundColor(Theme.inkMuted)
                    Text(L("garden.today"))
                        .font(.appMono(8)).tracking(1).foregroundColor(Theme.inkMuted)
                }
                .rotationEffect(.degrees(-7))
            }
            .frame(width: 74, height: 74)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L("home.goal.progress", dayDone, dailyGoal))
        .accessibilityHint(L("home.goal.stats.hint"))
    }

    private func streakCircle(_ streak: Int) -> some View {
        Button { showStreakDetail = true } label: {
            VStack(spacing: 2) {
                Text("\(streak)")
                    .font(.appDisplay(20))
                Text(L("garden.streak.days"))
                    .font(.appMono(8))
                    .tracking(1)
            }
            .foregroundStyle(Theme.vermillion)
            .frame(width: 62, height: 62)
            .overlay(Circle().strokeBorder(Theme.vermillion, lineWidth: 1.5))
            .rotationEffect(.degrees(-7))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L("home.streak.a11y", streak))
    }

    // MARK: - „Heute gießen"

    @ViewBuilder
    private var waterCard: some View {
        let due = DailyPlan.openWordCount(from: activeVocabs)
        Button { if due > 0 { showReview = true } } label: {
            HStack(spacing: 14) {
                Text("\(due)")
                    .font(.appDisplay(18))
                    .foregroundStyle(Color(hex: "#F2E9D8"))
                    .frame(width: 44, height: 44)
                    .background(due > 0 ? Theme.leaf : Theme.inkFaint, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(due > 0 ? L("garden.water.title") : L("garden.water.none.title"))
                        .font(.appHeadline)
                        .foregroundStyle(Theme.ink)
                    Text(due > 0
                         ? L("garden.water.subtitle", due, estimatedMinutes(due))
                         : L("garden.water.none.subtitle"))
                        .font(.appMono(13))
                        .foregroundStyle(Theme.inkSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 4)
                if due > 0 {
                    Text("→")
                        .font(.appDisplay(22, weight: .regular))
                        .foregroundStyle(Theme.vermillion)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .paperCard(padding: 14)
        }
        .buttonStyle(.plain)
        .disabled(due == 0)
        .accessibilityElement(children: .combine)
        .accessibilityHint(due > 0 ? L("home.today.a11y.hint") : "")
    }

    // MARK: - Gartenkarte (Beete)

    private var gardenCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("garden.beds.count", activeGroups.count))
                .font(.appMono(11))
                .tracking(1.3)
                .foregroundStyle(Theme.inkMuted)

            ForEach(Array(activeGroups.enumerated()), id: \.element.id) { index, group in
                NavigationLink { GroupDetailView(group: group) } label: {
                    bedRow(group, showNote: index == firstFallowIndex)
                }
                .buttonStyle(.plain)
            }

            gardenFooter
                .padding(.top, 2)
        }
        .padding(14)
        .background(
            LinearGradient(colors: [Theme.card, Theme.cardDeep], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
        .hardShadow()
    }

    private func bedRow(_ group: VocabGroup, showNote: Bool) -> some View {
        let fallow = isFallow(group)
        let color = Color(hex: group.colorHex)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(group.name)
                    .font(.appDisplay(15))
                    .foregroundStyle(fallow ? Theme.inkSecondary : Theme.ink)
                Spacer()
                Text(fallow
                     ? L("garden.fallow")
                     : "\(group.count(of: .learned))/\(group.vocabCount)")
                    .font(.appMono(11))
                    .foregroundStyle(Theme.inkMuted)
            }
            PlantRow(group: group)
                .grayscale(fallow ? 1 : 0)
                .opacity(fallow ? 0.5 : 1)
            if showNote {
                HandNote(L("garden.fallow.note", group.name, daysWaiting(group)))
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card.opacity(fallow ? 0.4 : 0.75))
        .groupAccent(fallow ? Theme.hairlineStrong : color, radius: 0)
    }

    // MARK: - Tages-Challenge

    private var challengeCard: some View {
        let c = DailyChallengeStore.snapshot()
        return HStack(spacing: 11) {
            Text(c.challenge.emoji)
                .font(.system(size: 18))
            VStack(alignment: .leading, spacing: 1) {
                Text(L("home.challenge.title"))
                    .font(.appMono(10)).tracking(1.2).textCase(.uppercase)
                    .foregroundStyle(Theme.inkMuted)
                Text(L(c.challenge.titleKey, c.target))
                    .font(.appDisplay(14))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 4) {
                if c.satisfied {
                    Text("✓").font(.appHeadline).foregroundStyle(Theme.leaf)
                } else {
                    Text(L("home.goal.progress", c.done, c.target))
                        .font(.appMono(12)).foregroundStyle(Theme.inkSecondary)
                }
                miniBar(fraction: c.fraction, color: Theme.ocher).frame(width: 46)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.card.opacity(0.6), in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Fuß der Gartenkarte: Wochenziel bzw. Gesamtzähler

    @ViewBuilder
    private var gardenFooter: some View {
        let review = WeeklyReviewStore.currentReview()
        if weeklyGoal > 0 || review.hasActivity {
            weeklyFooter(review)
        } else {
            HStack(alignment: .bottom) { Spacer(); totalCounter }
        }
    }

    private func weeklyFooter(_ review: WeeklyReview) -> some View {
        let target = max(weeklyGoal, 1)
        let fraction = weeklyGoal > 0 ? min(1, Double(weekDone) / Double(target)) : 0
        return VStack(alignment: .leading, spacing: 6) {
            Divider().overlay(Theme.hairline)
            HStack(alignment: .firstTextBaseline) {
                Text(L("home.weekly.title"))
                    .font(.appMono(10)).tracking(1.2).textCase(.uppercase)
                    .foregroundStyle(Theme.inkMuted)
                Spacer()
                if weeklyGoal > 0 {
                    Text("\(weekDone)").font(.appDisplay(14)).foregroundColor(Theme.leaf)
                        + Text(" / \(weeklyGoal)").font(.appMono(12)).foregroundColor(Theme.inkSecondary)
                }
            }
            if weeklyGoal > 0 {
                MasteryBar(fraction: fraction)
            }
            HStack(spacing: Theme.Spacing.s) {
                Text(L("garden.week.practiced", review.practicedCount))
                Spacer()
                Text(L("garden.week.bloomed", review.newlyLearnedCount))
                if let delta = review.deltaPercent {
                    Spacer()
                    Text(delta >= 0 ? L("garden.week.delta.up", delta) : L("garden.week.delta.down", abs(delta)))
                        .foregroundStyle(delta >= 0 ? Theme.vermillion : Theme.inkMuted)
                }
            }
            .font(.appMono(11))
            .foregroundStyle(Theme.inkSecondary)
        }
    }

    private func miniBar(fraction: Double, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(Theme.ink.opacity(0.06))
                RoundedRectangle(cornerRadius: 2).fill(color)
                    .frame(width: geo.size.width * max(0, min(fraction, 1)))
            }
        }
        .frame(height: 6)
        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Theme.hairline, lineWidth: 1))
    }

    private var totalCounter: some View {
        let learned = activeVocabs.filter { $0.status == .learned }.count
        return VStack(alignment: .trailing, spacing: 0) {
            Text(L("garden.learned.count", learned, activeVocabs.count))
            Text(L("garden.learned.label"))
        }
        .font(.appMono(11))
        .foregroundStyle(Theme.inkMuted)
        .multilineTextAlignment(.trailing)
    }

    // MARK: - Leerer Garten

    private var emptyGarden: some View {
        VStack(spacing: 16) {
            Text("🌱")
                .font(.system(size: 56))
            Text(L("garden.empty.title"))
                .font(.appBody)
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
            Button { showNewGroup = true } label: {
                Label(L("garden.empty.cta"), systemImage: "plus")
            }
            .buttonStyle(.primary)
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
    }

    // MARK: - Helfer

    private var dateText: String {
        let f = DateFormatter()
        f.locale = LocalizationManager.shared.localeForFormatting
        f.setLocalizedDateFormatFromTemplate("EEEE d MMM")
        return f.string(from: .now)
    }

    private func estimatedMinutes(_ due: Int) -> Int { max(1, Int(ceil(Double(due) * 0.5))) }

    /// Ein Beet liegt „brach", wenn es Wörter hat, nicht komplett gelernt ist und
    /// seit ≥7 Tagen nicht geübt wurde.
    private func isFallow(_ group: VocabGroup) -> Bool {
        guard group.vocabCount > 0, group.count(of: .learned) < group.vocabCount else { return false }
        return daysWaiting(group) >= 7
    }

    private func daysWaiting(_ group: VocabGroup) -> Int {
        let last = group.vocabs.compactMap { $0.lastPracticedAt }.max() ?? group.createdAt
        let days = Calendar.current.dateComponents([.day], from: last, to: .now).day ?? 0
        return max(0, days)
    }

    /// Index des am längsten brachliegenden Beets (für die einzelne Handnotiz).
    private var firstFallowIndex: Int? {
        activeGroups.enumerated()
            .filter { isFallow($0.element) }
            .max { daysWaiting($0.element) < daysWaiting($1.element) }?
            .offset
    }
}

#Preview {
    GardenHomeView()
        .modelContainer(PersistenceController.preview)
}
