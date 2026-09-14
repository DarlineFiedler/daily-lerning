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

    private var activeVocabs: [Vocab] { vocabs.filter { $0.group?.isArchived != true } }
    private var activeGroups: [VocabGroup] { groups.filter { !$0.isArchived } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    waterCard
                    if activeGroups.isEmpty {
                        emptyGarden
                    } else {
                        gardenCard
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .paperBackground()
            .navigationBarHidden(true)
            .onAppear {
                StreakStore.settle()
                GoalHistoryStore.snapshotToday()
            }
            .sheet(isPresented: $showReview) { ReviewSessionView() }
            .sheet(isPresented: $showNewGroup) { GroupEditView(group: nil) }
            .sheet(isPresented: $showStreakDetail) {
                StreakDetailView(streak: StreakStore.displayStreak(), longest: StreakStore.longest,
                                 jokers: StreakStore.availableJokers(), maxJokers: StreakStore.maxJokers,
                                 jokerUses: StreakStore.jokerUses, activeDays: StreakStore.activeDays)
            }
        }
    }

    // MARK: - Kopf (Datum + Titel + Streak-Kreis)

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(dateText)
                    .font(.appMono(13))
                    .foregroundStyle(Theme.inkSecondary)
                Text(L("garden.title"))
                    .font(.appDisplay(30))
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
            streakCircle
        }
        .padding(.horizontal, 6)
        .padding(.top, 4)
    }

    private var streakCircle: some View {
        let streak = StreakStore.displayStreak()
        return Button { showStreakDetail = true } label: {
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

            HStack(alignment: .bottom) {
                Spacer()
                totalCounter
            }
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
