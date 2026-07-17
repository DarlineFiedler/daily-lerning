import SwiftUI
import SwiftData

/// Tab 1: Einladendes Dashboard – Begrüßung, Wort des Tages, Fortschritt,
/// schneller Einstieg ins Üben und die eigenen Gruppen auf einen Blick.
struct HomeView: View {
    @Query(sort: \Vocab.createdAt) private var vocabs: [Vocab]
    @Query(sort: \VocabGroup.sortOrder) private var groups: [VocabGroup]

    @State private var revealWord: IdentifiableID?
    @State private var practiceGroup: VocabGroup?
    @State private var showingNewGroup = false
    @State private var showReview = false

    // MARK: Abgeleitete Werte

    private var learnedCount: Int { vocabs.filter { $0.status == .learned }.count }
    /// Heute fällige Wörter (SRS-lite) über alle Gruppen.
    private var dueCount: Int { vocabs.filter { $0.isDue() }.count }
    /// Aktueller Tages-Streak (0, wenn abgelaufen).
    private var streak: Int { StreakStore.displayStreak() }
    private var rate: Int {
        guard !vocabs.isEmpty else { return 0 }
        return Int(round(Double(learnedCount) / Double(vocabs.count) * 100))
    }
    private var overallCounts: [LearningStatus: Int] {
        Dictionary(uniqueKeysWithValues: LearningStatus.allCases.map { status in
            (status, vocabs.filter { $0.status == status }.count)
        })
    }

    /// Wort des Tages – stabil pro Kalendertag ausgewählt.
    private var wordOfDay: Vocab? {
        guard !vocabs.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: .now) ?? 0
        return vocabs[day % vocabs.count]
    }

    /// Empfohlene Gruppe zum Üben: die mit den meisten noch nicht gelernten Wörtern.
    private var recommendedGroup: VocabGroup? {
        groups.max { a, b in
            (a.vocabCount - a.count(of: .learned)) < (b.vocabCount - b.count(of: .learned))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.l) {
                    header
                    if vocabs.isEmpty {
                        emptyState
                    } else {
                        if dueCount > 0 { dueCard }
                        if let word = wordOfDay { wordOfDayCard(word) }
                        progressSection
                        startPracticeButton
                        groupsSection
                    }
                }
                .padding(Theme.Spacing.m)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(item: $revealWord) { WordRevealSheet(wordID: $0.id) }
            .sheet(item: $practiceGroup) { PracticeConfigView(preselected: [$0]) }
            .sheet(isPresented: $showingNewGroup) { GroupEditView(group: nil) }
            .sheet(isPresented: $showReview) { ReviewSessionView() }
        }
    }

    // MARK: - Header

    private var header: some View {
        GradientCard(gradient: Theme.brandGradient, radius: 28, padding: Theme.Spacing.l) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text("🇰🇷 안녕!")
                        .font(.appTitle3)
                        .opacity(0.9)
                    Spacer()
                    if streak > 0 { streakBadge }
                }
                Text(greeting)
                    .font(.appLargeTitle)
                Text(L("home.subtitle"))
                    .font(.appBody)
                    .opacity(0.9)
            }
        }
        .padding(.top, Theme.Spacing.m)
    }

    private var streakBadge: some View {
        Label(L("home.streak", streak), systemImage: "flame.fill")
            .font(.appCaption.weight(.bold))
            .padding(.horizontal, Theme.Spacing.s)
            .padding(.vertical, Theme.Spacing.xs)
            .background(.white.opacity(0.22), in: Capsule())
            .accessibilityLabel(L("home.streak.a11y", streak))
    }

    // MARK: - Heute fällig

    private var dueCard: some View {
        Button { showReview = true } label: {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: "bolt.heart.fill")
                    .font(.appTitle2)
                    .foregroundStyle(Theme.brandStart)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("home.due.title"))
                        .font(.appHeadline)
                        .foregroundStyle(.primary)
                    Text(L("home.due.count", dueCount))
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
        .accessibilityHint(L("home.due.a11y.hint"))
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return L("home.greeting.morning")
        case 12..<18: return L("home.greeting.afternoon")
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

    // MARK: - Fortschritt

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(L("home.progress"))
            HStack(spacing: Theme.Spacing.s) {
                StatTile(value: "\(vocabs.count)", label: L("home.stat.total"),
                         systemImage: "text.book.closed.fill", tint: Theme.brandStart)
                StatTile(value: "\(learnedCount)", label: L("home.stat.learned"),
                         systemImage: "checkmark.seal.fill", tint: LearningStatus.learned.color)
                StatTile(value: "\(rate)%", label: L("home.stat.rate"),
                         systemImage: "chart.pie.fill", tint: Theme.brandEnd)
            }
            StatusDistributionBar(counts: overallCounts, height: 14)
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
        if !groups.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                SectionHeader(L("home.groups"))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.m) {
                        ForEach(groups) { group in
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

#Preview {
    HomeView()
        .modelContainer(PersistenceController.preview)
}
