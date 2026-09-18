import SwiftData
import SwiftUI

/// **Screens 3a–3f — Geführter Erststart** (Issue 117).
/// Fünf überspringbare Schritte im Papier-Look, die ausschließlich vorhandene
/// Bausteine verdrahten (WordPack-Import, Tagesziel, Erinnerung, Widget). Danach
/// geht es direkt in den Garten; wird alles übersprungen, zeigt der Garten seinen
/// eigenen Leerzustand (3f).
struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \VocabGroup.sortOrder) private var groups: [VocabGroup]

    /// Wird gesetzt, wenn der Erststart abgeschlossen/übersprungen ist.
    let onFinish: () -> Void

    @AppStorage(GoalKeys.daily, store: AppGroup.defaults) private var dailyGoal = 0

    @State private var step = 0
    @State private var packs: [WordPack] = []
    @State private var importedPackID: String?
    @State private var importedCount = 0
    @State private var reminderOn = false
    @State private var reminderTime = Calendar.current.date(from: DateComponents(hour: 19, minute: 0)) ?? .now
    @State private var widgetPrepared = false

    private let stepCount = 5

    var body: some View {
        VStack(spacing: 0) {
            topBar
            TabView(selection: $step) {
                welcomeStep.tag(0)
                packStep.tag(1)
                goalStep.tag(2)
                reminderStep.tag(3)
                widgetStep.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeOut(duration: 0.2), value: step)
            bottomBar
        }
        .paperBackground()
        .onAppear { packs = WordPack.loadBundled() }
    }

    // MARK: - Kopf (Schrittzähler + Überspringen)

    private var topBar: some View {
        HStack {
            Text(L("onboarding.step", step + 1, stepCount))
                .monoLabel()
            Spacer()
            Button(L("onboarding.skip"), action: finish)
                .font(.appCaption)
                .foregroundStyle(Theme.inkMuted)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // MARK: - Untere Leiste (Weiter / In den Garten)

    private var bottomBar: some View {
        Button(action: advance) {
            Label(step == stepCount - 1 ? L("onboarding.finish") : L("onboarding.next"),
                  systemImage: step == stepCount - 1 ? "leaf.fill" : "arrow.right")
        }
        .buttonStyle(.primary)
        .padding(20)
    }

    // MARK: - Schritte

    private var welcomeStep: some View {
        stepScaffold(emoji: "🌷🌿🌱", title: L("onboarding.welcome.title"),
                     body: L("onboarding.welcome.body")) { EmptyView() }
    }

    private var packStep: some View {
        stepScaffold(emoji: "🪴", title: L("onboarding.pack.title"),
                     body: L("onboarding.pack.body")) {
            VStack(spacing: 10) {
                ForEach(packs.prefix(6)) { pack in
                    Button { importPack(pack) } label: {
                        HStack {
                            Text(pack.name)
                                .font(.appDisplay(15))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            if importedPackID == pack.id {
                                Text("✓").font(.appHeadline).foregroundStyle(Theme.leaf)
                            } else {
                                Text("\(pack.count)").font(.appMono(11)).foregroundStyle(Theme.inkMuted)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .paperCard(padding: 12,
                                   fill: importedPackID == pack.id ? Theme.leaf.opacity(0.14) : Theme.card)
                    }
                    .buttonStyle(.plain)
                }
                if importedCount > 0 {
                    HandNote(L("onboarding.pack.imported", importedCount)).padding(.top, 4)
                }
            }
        }
    }

    private var goalStep: some View {
        stepScaffold(emoji: "🎯", title: L("onboarding.goal.title"),
                     body: L("onboarding.goal.body")) {
            HStack(spacing: 10) {
                ForEach([5, 10, 20], id: \.self) { value in
                    goalChip(value: value, label: L("onboarding.goal.words", value))
                }
                goalChip(value: 0, label: L("onboarding.goal.none"))
            }
        }
    }

    private var reminderStep: some View {
        stepScaffold(emoji: "🔔", title: L("onboarding.reminder.title"),
                     body: L("onboarding.reminder.body")) {
            VStack(spacing: 14) {
                Toggle(L("onboarding.reminder.enable"), isOn: $reminderOn)
                    .font(.appBody)
                    .tint(Theme.leaf)
                    .onChange(of: reminderOn) { _, on in if on { enableReminder() } else { disableReminder() } }
                if reminderOn {
                    DatePicker(L("onboarding.reminder.time"), selection: $reminderTime, displayedComponents: .hourAndMinute)
                        .font(.appBody)
                        .onChange(of: reminderTime) { _, _ in enableReminder() }
                }
            }
            .paperCard(padding: 16)
        }
    }

    private var widgetStep: some View {
        stepScaffold(emoji: "✦", title: L("onboarding.widget.title"),
                     body: L("onboarding.widget.body")) {
            if widgetPrepared {
                Button {} label: {
                    Label(L("onboarding.widget.done"), systemImage: "checkmark")
                }
                .buttonStyle(.forward)
                .disabled(true)
            } else {
                Button { prepareWidget() } label: {
                    Label(L("onboarding.widget.enable"), systemImage: "star.fill")
                }
                .buttonStyle(.secondary(tint: Theme.ocher))
            }
        }
    }

    // MARK: - Gerüst eines Schritts

    private func stepScaffold<Control: View>(emoji: String, title: String, body: String,
                                             @ViewBuilder control: () -> Control) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                Text(emoji).font(.system(size: 56)).padding(.top, 24)
                Text(title)
                    .font(.appDisplay(26))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                Text(body)
                    .font(.appBody)
                    .foregroundStyle(Theme.inkSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                control().padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private func goalChip(value: Int, label: String) -> some View {
        let selected = dailyGoal == value
        return Button { dailyGoal = value } label: {
            Text(label)
                .font(.appMono(12))
                .foregroundStyle(selected ? Color(hex: "#FBF5EA") : Theme.ink)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(selected ? Theme.vermillion : Theme.card,
                            in: RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                        .strokeBorder(selected ? .clear : Theme.hairlineStrong, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Aktionen (nur vorhandene Bausteine)

    private func advance() {
        if step < stepCount - 1 { withAnimation { step += 1 } } else { finish() }
    }

    private func finish() {
        AppGroup.defaults.set(true, forKey: OnboardingState.completedKey)
        onFinish()
    }

    private func importPack(_ pack: WordPack) {
        let result = VocabImporter.importRows(pack.rows, intoGroupNamed: pack.name,
                                              context: context, existingGroups: groups)
        context.saveOrLog()
        AppContentRefresh.afterVocabChange(context: context)
        importedPackID = pack.id
        importedCount = result.added
    }

    private func enableReminder() {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let hour = comps.hour ?? 19, minute = comps.minute ?? 0
        Task {
            let granted = await NotificationScheduler.requestAuthorization()
            await MainActor.run {
                if granted {
                    AppGroup.defaults.set(true, forKey: ReminderKeys.enabled)
                    AppGroup.defaults.set(hour, forKey: ReminderKeys.hour)
                    AppGroup.defaults.set(minute, forKey: ReminderKeys.minute)
                    NotificationScheduler.schedule(hour: hour, minute: minute)
                } else {
                    reminderOn = false
                }
            }
        }
    }

    private func disableReminder() {
        AppGroup.defaults.set(false, forKey: ReminderKeys.enabled)
        NotificationScheduler.cancel()
    }

    /// Markiert die ersten Wörter fürs Widget (setzt `includeInWidget`) und frischt den
    /// Snapshot auf – so ist das Widget nach dem Erststart sofort befüllt.
    private func prepareWidget() {
        let vocabs = (try? context.fetch(FetchDescriptor<Vocab>())) ?? []
        for vocab in vocabs.prefix(8) { vocab.includeInWidget = true }
        context.saveOrLog()
        AppContentRefresh.afterVocabChange(context: context)
        widgetPrepared = true
    }
}

/// Zustands-Flag für den Erststart (im geteilten UserDefaults, damit App + Widget denselben
/// Stand sehen und der Erststart nach einem Neustart nicht erneut erscheint).
enum OnboardingState {
    static let completedKey = "onboarding.completed.v3"
    static var isCompleted: Bool { AppGroup.defaults.bool(forKey: completedKey) }
}

#Preview {
    OnboardingView(onFinish: {})
        .modelContainer(PersistenceController.preview)
}
