import SwiftData
import SwiftUI

/// Tab 1: Einladendes Dashboard – Begrüßung, Wort des Tages, Fortschritt,
/// schneller Einstieg ins Üben und die eigenen Gruppen auf einen Blick.
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Vocab.createdAt) private var vocabs: [Vocab]
    @Query(sort: \VocabGroup.sortOrder) private var groups: [VocabGroup]

    @State private var revealWord: IdentifiableID?
    @State private var practiceGroup: VocabGroup?
    @State private var showingNewGroup = false
    @State private var showReview = false
    @State private var showStreakDetail = false
    /// Blendet den Ziel-Statistik-Screen ein (Tippen auf die Ziel-Karte).
    @State private var showGoalStats = false
    /// Beim Erreichen des Wochenziels neu freigeschaltete Badges (fürs Banner).
    @State private var goalUnlocked: [Achievement] = []

    // MARK: Persönliches Ziel
    @AppStorage(GoalKeys.metric, store: AppGroup.defaults)
    private var goalMetricRaw = GoalMetric.practiced.rawValue
    @AppStorage(GoalKeys.weekly, store: AppGroup.defaults)
    private var weeklyGoal = GoalOptions.defaultWeekly
    @AppStorage(GoalKeys.daily, store: AppGroup.defaults)
    private var dailyGoal = GoalOptions.defaultDaily

    // MARK: Abgeleitete Werte

    /// Nur nicht-archivierte Wörter/Gruppen fließen ins Dashboard, den Tagesplan,
    /// die Fortschrittszahlen und die Übungsempfehlung ein – archivierte Gruppen
    /// sind „pausiert" und tauchen hier nicht mehr auf (siehe [[VocabGroup]] `isArchived`).
    private var activeVocabs: [Vocab] { vocabs.filter { $0.group?.isArchived != true } }
    private var activeGroups: [VocabGroup] { groups.filter { !$0.isArchived } }

    /// Aktueller Tages-Streak (0, wenn abgelaufen). Für die Streak-Detail-Sheet;
    /// im Dashboard-Hot-Path wird der Wert einmal in `scrollContent` gecacht.
    private var streak: Int { StreakStore.displayStreak() }
    /// Verfügbare Streak-Freeze-Joker.
    private var jokers: Int { StreakStore.availableJokers() }
    /// Gewählte Zielart (geübte vs. neu gelernte Wörter).
    private var goalMetric: GoalMetric { GoalMetric(rawValue: goalMetricRaw) ?? .practiced }
    /// Fortschritt der laufenden Woche bzw. des heutigen Tages gegen das Ziel.
    private var weekDone: Int { WeeklyReviewStore.weekProgress(for: goalMetric) }
    private var dayDone: Int { WeeklyReviewStore.dayProgress(for: goalMetric) }
    /// Ist überhaupt ein Ziel gesetzt (Tages- oder Wochenziel)?
    private var hasGoal: Bool { weeklyGoal > 0 || dailyGoal > 0 }

    /// Empfohlene Gruppe zum Üben: die mit den meisten noch nicht gelernten Wörtern.
    private var recommendedGroup: VocabGroup? {
        activeGroups.max { a, b in
            (a.vocabCount - a.count(of: .learned)) < (b.vocabCount - b.count(of: .learned))
        }
    }

    var body: some View {
        NavigationStack {
            scrollContent
            .background(Theme.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .overlay(alignment: .top) {
                AchievementUnlockBanner(achievements: goalUnlocked)
            }
            .onAppear {
                StreakStore.settle()
                GoalHistoryStore.snapshotToday()
                checkWeeklyGoal()
            }
            .sheet(item: $revealWord) { WordRevealSheet(wordID: $0.id) }
            .sheet(item: $practiceGroup) { _ in PracticeConfigView() }
            .sheet(isPresented: $showingNewGroup) { GroupEditView(group: nil) }
            .sheet(isPresented: $showReview) { ReviewSessionView() }
            .sheet(isPresented: $showGoalStats) {
                GoalStatsView()
            }
            .sheet(isPresented: $showStreakDetail) {
                StreakDetailView(streak: streak, longest: StreakStore.longest,
                                 jokers: jokers, maxJokers: StreakStore.maxJokers,
                                 jokerUses: StreakStore.jokerUses,
                                 activeDays: StreakStore.activeDays)
            }
        }
    }

    /// Dashboard-Inhalt. Die teuren Werte (aktive Wörter, Status-Verteilung,
    /// Tagesplan, Wochenrückblick, Streak/Joker) werden hier **einmal** je Render
    /// berechnet und in die Teil-Views durchgereicht – statt sie in mehreren
    /// computed properties erneut zu filtern/dekodieren.
    private var scrollContent: some View {
        let active = activeVocabs
        let streak = StreakStore.displayStreak()
        let jokers = StreakStore.availableJokers()
        let level = XPStore.level
        return ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                header(streak: streak, jokers: jokers, level: level)
                if active.isEmpty {
                    emptyState
                } else {
                    let counts = active.statusCounts()
                    let plan = DailyPlan.today(from: active)
                    let review = WeeklyReviewStore.currentReview()
                    todayCard(plan)
                    dailyChallengeCard
                    if review.hasActivity { weeklyReviewCard(review) }
                    if hasGoal { goalCard }
                    if let word = WordOfDay.pick(from: active) { wordOfDayCard(word) }
                    progressSection(active: active, counts: counts)
                    startPracticeButton
                    groupsSection
                }
            }
            .padding(Theme.Spacing.m)
            .padding(.bottom, Theme.Spacing.xl)
        }
    }

    // MARK: - Header

    private func header(streak: Int, jokers: Int, level: XPLevel) -> some View {
        GradientCard(gradient: Theme.brandGradient, radius: 28, padding: Theme.Spacing.l) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text("🇰🇷 안녕!")
                        .font(.appTitle3)
                        .opacity(0.9)
                    Spacer()
                    if streak > 0 || jokers > 0 { streakCluster(streak: streak, jokers: jokers) }
                }
                Text(greeting)
                    .font(.appLargeTitle)
                Text(L("home.subtitle"))
                    .font(.appBody)
                    .opacity(0.9)
                levelBadge(level)
                    .padding(.top, Theme.Spacing.xs)
            }
        }
        .padding(.top, Theme.Spacing.m)
    }

    /// Persistente Fortschrittsanzeige: aktuelles Level und thematischer Rangname.
    /// Rein informativ (kein Button) – XP wächst mit jeder geübten Vokabel.
    private func levelBadge(_ level: XPLevel) -> some View {
        Label("\(L("home.level", level.level)) · \(L(level.rankKey))", systemImage: "star.fill")
            .font(.appCaption.weight(.bold))
            .lineLimit(1)
            .padding(.horizontal, Theme.Spacing.s)
            .padding(.vertical, Theme.Spacing.xs)
            .background(.white.opacity(0.22), in: Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L("home.level.a11y", level.level, L(level.rankKey)))
    }

    /// Tappbare Badge-Gruppe (Streak + Joker) – öffnet die Detailansicht.
    private func streakCluster(streak: Int, jokers: Int) -> some View {
        Button { showStreakDetail = true } label: {
            HStack(spacing: Theme.Spacing.xs) {
                if streak > 0 { streakBadge(streak) }
                if jokers > 0 { jokerBadge(jokers) }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(L("home.streak.detail.hint"))
    }

    private func streakBadge(_ streak: Int) -> some View {
        badge(L("home.streak", streak), systemImage: "flame.fill")
            .accessibilityLabel(L("home.streak.a11y", streak))
    }

    private func jokerBadge(_ jokers: Int) -> some View {
        badge("\(jokers)", systemImage: "snowflake")
            .accessibilityLabel(L("home.jokers.a11y", jokers))
    }

    private func badge(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.appCaption.weight(.bold))
            .padding(.horizontal, Theme.Spacing.s)
            .padding(.vertical, Theme.Spacing.xs)
            .background(.white.opacity(0.22), in: Capsule())
    }

    // MARK: - Heutiger Tagesplan

    @ViewBuilder
    private func todayCard(_ plan: DailyPlan.Result) -> some View {
        switch plan.kind {
        case .learn:
            todayActionCard(icon: "bolt.heart.fill",
                            title: L("home.today.learn.title"),
                            subtitle: L("home.today.learn.count", plan.words.count))
        case .review:
            todayActionCard(icon: "arrow.triangle.2.circlepath",
                            title: L("home.today.review.title"),
                            subtitle: L("home.today.review.count", plan.words.count))
        case .done:
            todayDoneCard
        case .none:
            EmptyView()
        }
    }

    /// Tappbare Karte, die die heutige Runde startet.
    private func todayActionCard(icon: String, title: String, subtitle: String) -> some View {
        Button { showReview = true } label: {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: icon)
                    .font(.appTitle2)
                    .foregroundStyle(Theme.brandStart)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.appHeadline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.appSubheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.appHeadline)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(padding: Theme.Spacing.l)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(L("home.today.a11y.hint"))
    }

    /// „Heute alles erledigt" – nicht tappbarer Erfolgs-Zustand.
    private var todayDoneCard: some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: "checkmark.circle.fill")
                .font(.appTitle2)
                .foregroundStyle(LearningStatus.learned.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(L("home.today.done.title"))
                    .font(.appHeadline)
                    .foregroundStyle(.primary)
                Text(L("home.today.done.subtitle"))
                    .font(.appSubheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: Theme.Spacing.l)
        .accessibilityElement(children: .combine)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5 ..< 12: return L("home.greeting.morning")
        case 12 ..< 18: return L("home.greeting.afternoon")
        default: return L("home.greeting.evening")
        }
    }

    // MARK: - Wort des Tages

    private func wordOfDayCard(_ word: Vocab) -> some View {
        Button { revealWord = IdentifiableID(id: word.id) } label: {
            VStack(alignment: .leading, spacing: 10) {
                Label(L("home.wordOfDay"), systemImage: "sparkles")
                    .font(.appCaption.weight(.semibold))
                    .foregroundStyle(Theme.brandStart)
                HStack(alignment: .firstTextBaseline) {
                    Text(word.word)
                        .font(.appDisplay(34))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.appHeadline)
                        .foregroundStyle(.tertiary)
                }
                Text(word.meaning)
                    .font(.appTitle3)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(padding: Theme.Spacing.l)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Wochenrückblick

    /// Kompakte Karte mit den Zahlen der letzten abgeschlossenen Woche.
    private func weeklyReviewCard(_ review: WeeklyReview) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Label(L("home.weekly.title"), systemImage: "calendar")
                    .font(.appCaption.weight(.semibold))
                    .foregroundStyle(Theme.brandStart)
                Spacer()
                Text(weekRangeText(review.weekStart))
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: Theme.Spacing.s) {
                StatTile(value: "\(review.practicedCount)", label: L("home.weekly.practiced"),
                         systemImage: "checkmark.circle.fill", tint: Theme.brandStart)
                StatTile(value: "\(review.newlyLearnedCount)", label: L("home.weekly.learned"),
                         systemImage: "star.fill", tint: LearningStatus.learned.color)
                StatTile(value: "\(review.streak)", label: L("home.weekly.streak"),
                         systemImage: "flame.fill", tint: Theme.brandEnd)
            }
            if let delta = review.deltaPercent {
                Label(weeklyDeltaText(delta), systemImage: deltaIcon(delta))
                    .font(.appCaption.weight(.medium))
                    .foregroundStyle(delta >= 0 ? LearningStatus.learned.color : .secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: Theme.Spacing.l)
        .accessibilityElement(children: .combine)
    }

    /// „14.–20. Juli" – lokalisierter Datumsbereich der Rückblick-Woche. Nutzt die
    /// in-App gewählte Sprache (nicht die Geräte-Locale), konsistent mit den übrigen
    /// Datumsausgaben. `DateIntervalFormatter` liest die SwiftUI-`\.locale` nicht,
    /// daher muss sie explizit gesetzt werden.
    private func weekRangeText(_ weekStart: Date) -> String {
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let formatter = DateIntervalFormatter()
        formatter.calendar = calendar
        formatter.locale = LocalizationManager.shared.localeForFormatting
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: weekStart, to: end)
    }

    private func weeklyDeltaText(_ delta: Int) -> String {
        delta >= 0 ? L("home.weekly.delta.up", delta) : L("home.weekly.delta.down", abs(delta))
    }

    private func deltaIcon(_ delta: Int) -> String {
        delta >= 0 ? "arrow.up.right" : "arrow.down.right"
    }

    // MARK: - Fortschritt

    private func progressSection(active: [Vocab], counts: [LearningStatus: Int]) -> some View {
        let learned = counts[.learned] ?? 0
        let rate = active.isEmpty ? 0 : Int(round(Double(learned) / Double(active.count) * 100))
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(L("home.progress"))
            HStack(spacing: Theme.Spacing.s) {
                NavigationLink { WordListView(titleKey: "words.all.title") } label: {
                    StatTile(value: "\(active.count)", label: L("home.stat.total"),
                             systemImage: "text.book.closed.fill", tint: Theme.brandStart)
                }
                .buttonStyle(.plain)
                NavigationLink {
                    WordListView(titleKey: "words.learned.title", lockedStatus: .learned)
                } label: {
                    StatTile(value: "\(learned)", label: L("home.stat.learned"),
                             systemImage: "checkmark.seal.fill", tint: LearningStatus.learned.color)
                }
                .buttonStyle(.plain)
                NavigationLink { MasteryView() } label: {
                    StatTile(value: "\(rate)%", label: L("home.stat.rate"),
                             systemImage: "chart.pie.fill", tint: Theme.brandEnd)
                }
                .buttonStyle(.plain)
            }
            StatusDistributionBar(counts: counts, height: 14)
                .padding(.top, Theme.Spacing.xs)
        }
    }

    // MARK: - Üben-CTA

    @ViewBuilder
    private var startPracticeButton: some View {
        if let group = recommendedGroup, group.vocabCount > 0 {
            Button { practiceGroup = group } label: {
                Label(L("home.startPractice"), systemImage: "play.fill")
            }
            .buttonStyle(.primary)
        }
    }

    // MARK: - Gruppen

    @ViewBuilder
    private var groupsSection: some View {
        if !activeGroups.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                SectionHeader(L("home.groups"))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.m) {
                        ForEach(activeGroups) { group in
                            NavigationLink { GroupDetailView(group: group) } label: {
                                groupChip(group)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                }
            }
        }
    }

    private func groupChip(_ group: VocabGroup) -> some View {
        GradientCard(gradient: .forHex(group.colorHex), padding: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "rectangle.stack.fill")
                    .font(.appTitle2)
                Text(group.name)
                    .font(.appHeadline)
                    .lineLimit(1)
                Text(L("group.wordCount", group.vocabCount))
                    .font(.appCaption)
                    .opacity(0.9)
            }
        }
        .frame(width: 150)
    }

    // MARK: - Leerzustand

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "sparkles")
                .font(.system(size: 52))
                .foregroundStyle(Theme.brandGradient)
            Text(L("home.empty"))
                .font(.appBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button { showingNewGroup = true } label: {
                Label(L("home.emptyCTA"), systemImage: "plus")
            }
            .buttonStyle(.primary)
            .padding(.horizontal, Theme.Spacing.xl)
        }
        .padding(.top, Theme.Spacing.xl)
    }
}

// MARK: - Persönliches Ziel

/// Ziel-bezogene Ansichten und Logik. Bewusst als Extension ausgelagert, damit der
/// primäre `HomeView`-Body unter dem SwiftLint-`type_body_length`-Limit bleibt.
extension HomeView {
    /// Karte mit dem Fortschritt gegen das selbst gesetzte Tages-/Wochenziel für die
    /// laufende Woche bzw. den heutigen Tag. Zeigt nur die aktiven Ziel-Ebenen (Wert > 0).
    private var goalCard: some View {
        Button {
            showGoalStats = true
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                HStack {
                    Label(L("home.goal.title"), systemImage: "target")
                        .font(.appCaption.weight(.semibold))
                        .foregroundStyle(Theme.brandStart)
                    Spacer()
                    Image(systemName: "chart.bar.xaxis")
                        .font(.appCaption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                if dailyGoal > 0 {
                    goalRow(labelKey: "home.goal.today", done: dayDone, target: dailyGoal)
                }
                if weeklyGoal > 0 {
                    goalRow(labelKey: "home.goal.week", done: weekDone, target: weeklyGoal)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(padding: Theme.Spacing.l)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(L("home.goal.stats.hint"))
    }

    /// Eine Ziel-Ebene (Tag oder Woche): Label, Zähler „6 / 10" bzw. „erreicht"-Häkchen
    /// und ein Fortschrittsbalken.
    @ViewBuilder
    private func goalRow(labelKey: String, done: Int, target: Int) -> some View {
        let fraction = target > 0 ? min(1, Double(done) / Double(target)) : 0
        let reached = done >= target
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text(L(labelKey))
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                Spacer()
                if reached {
                    Label(L("home.goal.reached"), systemImage: "checkmark.circle.fill")
                        .font(.appCaption.weight(.semibold))
                        .foregroundStyle(LearningStatus.learned.color)
                } else {
                    Text(L("home.goal.progress", done, target))
                        .font(.appCaption.weight(.semibold))
                        .monospacedDigit()
                }
            }
            GoalProgressBar(fraction: fraction, reached: reached)
        }
    }

    /// Schaltet beim Erreichen des Wochenziels einmalig das „Zielstrebig"-Badge frei.
    /// Idempotent (Flag im Fortschritt); bei Neu-Freischaltung erscheint das Banner.
    private func checkWeeklyGoal() {
        guard weeklyGoal > 0, weekDone >= weeklyGoal else { return }
        let unlocked = AchievementService.recordEvent(\.weeklyGoalReached, context: context)
        if !unlocked.isEmpty { goalUnlocked = unlocked }
    }
}

// MARK: - Tages-Challenge

/// Ansicht der tagesaktuellen Mini-Challenge. Wie die Ziel-Karte als Extension
/// ausgelagert, damit der primäre `HomeView`-Body kompakt bleibt.
extension HomeView {
    /// Heutige Challenge inkl. Fortschritt (aus dem Achievement-Tagespuffer).
    private var challenge: DailyChallengeSnapshot { DailyChallengeStore.snapshot() }

    /// Mini-Streak „X Tage in Folge erfüllt" (0 = nicht anzeigen).
    private var challengeStreak: Int { DailyChallengeStore.displayStreak() }

    /// Karte mit der heutigen Mini-Challenge: Titel + Emoji, Fortschritt und Häkchen
    /// bei Erfüllung, dazu der eigene Mini-Streak.
    var dailyChallengeCard: some View {
        let c = challenge
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                Label(L("home.challenge.title"), systemImage: "flag.checkered")
                    .font(.appCaption.weight(.semibold))
                    .foregroundStyle(Theme.brandStart)
                Spacer()
                if challengeStreak > 0 {
                    Label(L("home.challenge.streak", challengeStreak), systemImage: "flame.fill")
                        .font(.appCaption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: Theme.Spacing.s) {
                Text(c.challenge.emoji)
                    .font(.appTitle2)
                Text(L(c.challenge.titleKey, c.target))
                    .font(.appHeadline)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            HStack {
                if c.satisfied {
                    Label(L("home.challenge.done"), systemImage: "checkmark.circle.fill")
                        .font(.appCaption.weight(.semibold))
                        .foregroundStyle(LearningStatus.learned.color)
                } else {
                    Text(L("home.goal.progress", c.done, c.target))
                        .font(.appCaption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            GoalProgressBar(fraction: c.fraction, reached: c.satisfied)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: Theme.Spacing.l)
        .accessibilityElement(children: .combine)
    }
}

/// Schlanker Fortschrittsbalken für die Ziel-Karte (helle `.cardStyle`-Fläche).
/// Bei Zielerreichung wechselt die Füllung auf die „Gelernt"-Farbe.
private struct GoalProgressBar: View {
    let fraction: Double
    let reached: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surfaceMuted)
                Capsule()
                    .fill(reached ? LearningStatus.learned.color : Theme.brandStart)
                    .frame(width: geo.size.width * max(0, min(fraction, 1)))
            }
        }
        .frame(height: 10)
    }
}

#Preview {
    HomeView()
        .modelContainer(PersistenceController.preview)
}
