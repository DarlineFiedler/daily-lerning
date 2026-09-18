import Combine
import SwiftUI

/// Führt durch eine TOPIK-Prüfungssimulation (Issue #94): ein Countdown-Kopf über der
/// laufenden Runde, die passende Modus-Karte pro Wort und am Ende der Prüfungs-Auswertung
/// (Bestanden/Nicht bestanden + Prozent). Reine Präsentation über eine normale
/// `PracticeSession` – die Runde zählt regulär in SRS/XP/Streak; nur Zeitlimit und
/// Ergebnis-Screen liegen hier darüber. Bewusst schlank wie [[BossBattleContainerView]]
/// (keine Live Activity). Score/Grenzen kommen aus [[ExamRules]].
struct ExamContainerView: View {
    @State var session: PracticeSession
    /// Das geprüfte TOPIK-Niveau (für Bestehensgrenze und Anzeige). `nil` = gemischt.
    var level: TopikLevel?
    /// Beendet die Prüfung (schließt den Navigations-Fluss).
    var onClose: () -> Void

    /// Zeitpunkt, an dem die Zeit abläuft (beim Erscheinen gesetzt).
    @State private var deadline = Date()
    /// Aktueller Tick (treibt die Countdown-Anzeige, im Timer fortgeschrieben).
    @State private var now = Date()
    /// Die Zeit ist abgelaufen → Runde vorzeitig auswerten.
    @State private var timedOut = false
    /// Countdown erst nach dem ersten Erscheinen starten (nicht in der Leer-Runde).
    @State private var started = false

    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    /// Gesamtes Zeitbudget der Prüfung in Sekunden.
    private var totalSeconds: Int { ExamRules.duration(wordCount: session.total) }

    /// Verbleibende Sekunden (nie negativ), aufgerundet für eine ruhige Sekunden-Anzeige.
    private var remaining: Int { max(0, Int(deadline.timeIntervalSince(now).rounded(.up))) }

    /// Prüfung vorbei: alle Wörter beantwortet oder Zeit abgelaufen.
    private var isFinished: Bool { session.isFinished || timedOut }

    var body: some View {
        VStack(spacing: 0) {
            if session.total == 0 {
                emptyState
            } else if isFinished {
                ExamResultView(session: session, level: level,
                               onRestart: restart, onClose: onClose)
            } else if let item = session.currentItem {
                ExamCountdownHeader(remaining: remaining, total: totalSeconds,
                                    position: session.position, count: session.total,
                                    level: level, onCancel: handleClose)
                ScrollView {
                    card(for: item)
                        .padding(Theme.Spacing.m)
                        .id(session.index) // erzwingt frische State pro Wort
                }
                examRubric
            }
        }
        .paperBackground()
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sensoryFeedback(.success, trigger: session.correctCount)
        .sensoryFeedback(.error, trigger: session.wrongCount)
        .onAppear(perform: startCountdown)
        .onReceive(timer) { date in
            guard started, !isFinished else { return }
            now = date
            if now >= deadline { timeUp() }
        }
        // Gesammelten Fortschritt sichern, wenn die Prüfung vorzeitig verlassen wird.
        .onDisappear { session.flushProgress() }
    }

    /// Setzt Countdown & Tick-Basis. Nur einmal – bei `restart` läuft es über `restart()`.
    private func startCountdown() {
        guard !started, session.total > 0 else { return }
        started = true
        now = Date()
        deadline = now.addingTimeInterval(TimeInterval(totalSeconds))
    }

    /// Zeit abgelaufen: Runde auswerten (unbeantwortete Wörter zählen als falsch) und den
    /// gesammelten Fortschritt persistieren – die reguläre Runden-Auswertung läuft nur bei
    /// vollständig durchlaufener Runde, deshalb hier explizit flushen.
    private func timeUp() {
        guard !timedOut else { return }
        timedOut = true
        session.flushProgress()
    }

    /// Startet dieselbe Prüfung neu und setzt den Countdown zurück.
    private func restart() {
        withAnimation { session.restart() }
        timedOut = false
        now = Date()
        deadline = now.addingTimeInterval(TimeInterval(totalSeconds))
    }

    private func handleClose() {
        session.flushProgress()
        onClose()
    }

    /// Angezeigtes Niveau – konkretes TOPIK-Level oder generisch „TOPIK".
    private var levelText: String {
        level.map { L($0.titleKey) } ?? "TOPIK"
    }

    /// Bewertungs-Panel am unteren Rand (Design-Handoff 2c): gestricheltes Kärtchen mit
    /// Bestehensgrenze, Zeit pro Frage und einer grünen Handschrift-Notiz.
    private var examRubric: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionLabel(L("practice.exam.rubric"))
            HStack {
                Text(L("practice.exam.passMark", levelText))
                    .font(.appSubheadline).foregroundStyle(Theme.ink)
                Spacer()
                Text("\(ExamRules.passMark(for: level))%")
                    .font(.appMono(13)).foregroundStyle(Theme.ink)
            }
            HStack {
                Text(L("practice.exam.timePerQuestion"))
                    .font(.appSubheadline).foregroundStyle(Theme.ink)
                Spacer()
                Text(L("practice.exam.seconds", ExamRules.secondsPerWord))
                    .font(.appMono(13)).foregroundStyle(Theme.ink)
            }
            Text(L("practice.exam.countsNote"))
                .font(.appHand(16)).foregroundStyle(Theme.leaf)
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
            .fill(Theme.card.opacity(0.6)))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
            .strokeBorder(Theme.hairlineStrong, style: StrokeStyle(lineWidth: 1.5, dash: [4])))
        .padding(Theme.Spacing.m)
    }

    @ViewBuilder
    private func card(for item: PracticeItem) -> some View {
        let onAnswer: (Bool) -> Void = { correct in
            withAnimation { session.submit(correct: correct) }
        }
        switch item.mode {
        case .multipleChoice:
            MultipleChoiceView(item: item, onAnswer: onAnswer)
        case .review:
            ReviewSwipeView(item: item, onAnswer: onAnswer)
        case .writing:
            WritingView(item: item, onAnswer: onAnswer)
        case .listening:
            ListeningView(item: item, onAnswer: onAnswer)
        case .cloze:
            ClozeView(item: item, onAnswer: onAnswer)
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "graduationcap")
                .font(.system(size: 52))
                .foregroundStyle(Theme.brandStart)
            Text(L("practice.exam.empty"))
                .font(.appBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(L("common.done"), action: onClose)
                .buttonStyle(.primary)
                .padding(.horizontal, Theme.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.Spacing.l)
    }
}

/// Countdown-Kopf der Prüfung: verbleibende Zeit (mm:ss) plus Position, mit einer
/// schrumpfenden Zeit-Leiste. Wird rot/dringlich, wenn die Zeit knapp wird.
struct ExamCountdownHeader: View {
    let remaining: Int
    let total: Int
    let position: Int
    let count: Int
    let level: TopikLevel?
    var onCancel: () -> Void

    /// Ab dieser Restzeit (Sekunden) wird der Countdown warnend rot.
    private static let urgentSeconds = 10

    private var isUrgent: Bool { remaining <= Self.urgentSeconds }
    private var timerColor: Color { isUrgent ? Theme.wrong : Theme.vermillion }

    /// Fortschritt = beantwortete Fragen (nicht Restzeit), Design-Handoff 2c.
    private var questionFraction: Double {
        count == 0 ? 0 : Double(position) / Double(count)
    }

    private var clock: String {
        String(format: "%d:%02d", remaining / 60, remaining % 60)
    }

    private var levelText: String {
        level.map { L($0.titleKey) } ?? "TOPIK"
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            // Reihe 1: Abbrechen (links) · gerahmter Timer (rechts).
            HStack {
                Button(action: onCancel) {
                    Text(L("common.cancel"))
                        .font(.appCaption)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.inkSecondary)
                }
                .buttonStyle(.plain)
                Spacer()
                Text(clock)
                    .font(.appMono(15, bold: true).monospacedDigit())
                    .foregroundStyle(timerColor)
                    .contentTransition(.numericText())
                    .padding(.vertical, 5)
                    .padding(.horizontal, 12)
                    .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(timerColor, lineWidth: 1.5))
            }

            // Reihe 2: Serif-Titel (links) · Fragezähler (rechts).
            HStack(alignment: .firstTextBaseline) {
                Text(L("practice.exam.titleFormat", levelText))
                    .font(.appTitle)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text(L("practice.exam.question", position, count))
                    .font(.appCaption)
                    .foregroundStyle(Theme.inkSecondary)
            }

            // Reihe 3: Frage-Fortschritt (grün).
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.hairline)
                    Capsule().fill(Theme.leaf)
                        .frame(width: geo.size.width * questionFraction)
                        .animation(.easeOut(duration: 0.3), value: questionFraction)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.top, Theme.Spacing.s)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("practice.exam.a11y.time", remaining))
    }
}

/// Prüfungs-Auswertung: Bestanden/Nicht bestanden im Prüfungs-Look, prominenter
/// Prozent-Score und Kennzahlen (richtig/gesamt, Niveau). Werte aus [[ExamRules]].
struct ExamResultView: View {
    let session: PracticeSession
    let level: TopikLevel?
    var onRestart: () -> Void
    var onClose: () -> Void

    @State private var appeared = false

    private var score: Int {
        ExamRules.score(correct: session.correctCount, total: session.total)
    }

    private var passed: Bool {
        ExamRules.passed(correct: session.correctCount, total: session.total, level: level)
    }

    /// Angezeigtes Niveau – konkret gewähltes TOPIK-Level oder generisch „TOPIK".
    private var levelText: String {
        level.map { L($0.titleKey) } ?? "TOPIK"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                Text(passed ? "🎓" : "📄")
                    .font(.system(size: 72))
                    .scaleEffect(appeared ? 1 : 0.4)
                    .rotationEffect(.degrees(appeared ? 0 : -20))
                Text(L(passed ? "practice.exam.passed" : "practice.exam.failed"))
                    .font(.appLargeTitle)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(passed ? LearningStatus.learned.color : Theme.wrong)

                Text(L("practice.exam.score", score))
                    .font(.appDisplay(52))
                    .foregroundStyle(Theme.brandGradient)

                HStack(spacing: Theme.Spacing.s) {
                    StatTile(value: "\(session.correctCount) / \(session.total)",
                             label: L("practice.exam.stat.correct"),
                             systemImage: "checkmark", tint: LearningStatus.learned.color)
                    StatTile(value: levelText, label: L("practice.exam.stat.level"),
                             systemImage: "graduationcap.fill", tint: Theme.brandMid)
                }

                VStack(spacing: Theme.Spacing.s) {
                    Button(action: onRestart) {
                        Label(L("practice.restart"), systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.primary)
                    Button(action: onClose) {
                        Text(L("common.done"))
                    }
                    .buttonStyle(.secondary)
                }
            }
            .padding(Theme.Spacing.l)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appeared = true }
        }
    }
}
