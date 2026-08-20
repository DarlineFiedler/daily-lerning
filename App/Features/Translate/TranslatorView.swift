import SwiftUI
import Translation

/// DeepL-artiger Übersetzer: Text eingeben, Übersetzung erhalten und beide Seiten
/// vorlesen lassen. Übersetzt on-device via Apples Translation-Framework (iOS 18+),
/// Sprachausgabe über den vorhandenen [[SpeakButton]]. Richtung Koreanisch ↔ App-Sprache,
/// automatisch erkannt via [[TranslationDirection]] mit Tausch-Möglichkeit.
struct TranslatorView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if #available(iOS 18.0, *) {
                    TranslatorContentView()
                } else {
                    ContentUnavailableView(L("translator.unavailable"),
                                           systemImage: "character.bubble",
                                           description: Text(L("translator.unavailable.detail")))
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(L("translator.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.done")) { dismiss() }
                }
            }
        }
    }
}

/// Eigentlicher Übersetzer-Inhalt – trägt den `TranslationSession.Configuration`-State
/// und darf daher erst ab iOS 18 existieren.
@available(iOS 18.0, *)
private struct TranslatorContentView: View {
    @State private var sourceText = ""
    @State private var translatedText = ""
    @State private var isTranslating = false
    @State private var errorText: String?
    @State private var copied = false

    /// Löst die Übersetzung aus; wird bei jeder (Neu-)Anforderung gesetzt bzw. invalidiert.
    @State private var configuration: TranslationSession.Configuration?

    /// Nicht-korenische Gegenseite, abgeleitet aus der UI-/System-Sprache. Ändert sich
    /// während der Lebensdauer des Sheets nicht – daher einmalig bei Init berechnet.
    private let appLang = TranslationDirection.resolvedAppLang(
        language: LocalizationManager.shared.language,
        deviceCode: Locale.preferredLanguages.first
            .flatMap { Locale(identifier: $0).language.languageCode?.identifier } ?? "en")

    private var pair: TranslationDirection.LanguagePair {
        TranslationDirection.pair(for: sourceText, appLang: appLang)
    }

    private var trimmedInput: String {
        sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.m) {
                languageBar
                inputCard
                Button(L("translator.translate")) { translate() }
                    .buttonStyle(.primary)
                    .disabled(trimmedInput.isEmpty)
                outputCard
            }
            .padding(Theme.Spacing.m)
        }
        .scrollDismissesKeyboard(.interactively)
        .translationTask(configuration) { session in
            await runTranslation(with: session)
        }
    }

    // MARK: - Kopfleiste mit Sprachen + Tausch

    private var languageBar: some View {
        HStack(spacing: Theme.Spacing.s) {
            Text(TranslationDirection.label(for: pair.source))
                .frame(maxWidth: .infinity)
            Button {
                swap()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.appHeadline)
            }
            .buttonStyle(.plain)
            .foregroundStyle(translatedText.isEmpty ? Color.secondary : Theme.brandStart)
            .disabled(translatedText.isEmpty)
            .accessibilityLabel(L("translator.swap.a11y"))
            Text(TranslationDirection.label(for: pair.target))
                .frame(maxWidth: .infinity)
        }
        .font(.appHeadline)
        .foregroundStyle(.primary)
        .cardStyle()
    }

    // MARK: - Eingabe

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            ZStack(alignment: .topLeading) {
                if sourceText.isEmpty {
                    Text(L("translator.input.placeholder"))
                        .font(.appBody)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $sourceText)
                    .font(.appBody)
                    .frame(minHeight: 110)
                    .scrollContentBackground(.hidden)
            }
            HStack {
                SpeakButton(text: sourceText, language: pair.sourceTTS)
                Spacer()
                if !sourceText.isEmpty {
                    Button(L("translator.clear")) {
                        sourceText = ""
                        translatedText = ""
                        errorText = nil
                    }
                    .font(.appSubheadline)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Ausgabe

    private var outputCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            if isTranslating {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, Theme.Spacing.m)
            } else if let errorText {
                Text(errorText)
                    .font(.appBody)
                    .foregroundStyle(Theme.wrong)
            } else if translatedText.isEmpty {
                Text(L("translator.output.placeholder"))
                    .font(.appBody)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(translatedText)
                    .font(.appBody)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                HStack {
                    SpeakButton(text: translatedText, language: pair.targetTTS)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = translatedText
                        copied = true
                        Task {
                            try? await Task.sleep(for: .seconds(1.5))
                            copied = false
                        }
                    } label: {
                        Label(copied ? L("translator.copied") : L("translator.copy"),
                              systemImage: copied ? "checkmark" : "doc.on.doc")
                            .font(.appSubheadline)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.brandStart)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - Übersetzung

    /// Tauscht Eingabe und Ergebnis (DeepL-artig) und übersetzt neu. Da die Richtung
    /// stets aus dem Eingabetext erkannt wird, folgt sie automatisch dem vertauschten
    /// Inhalt – kein separater Zustand, der aus dem Tritt geraten kann.
    private func swap() {
        guard !translatedText.isEmpty else { return }
        let previousInput = sourceText
        sourceText = translatedText
        translatedText = previousInput
        errorText = nil
        translate()
    }

    private func translate() {
        guard !trimmedInput.isEmpty else { return }
        errorText = nil
        // Bei Hangul explizit Koreanisch als Quelle; sonst Quelle automatisch erkennen
        // lassen (nil), damit auch andere Eingabesprachen korrekt nach Ko übersetzt werden.
        let koreanIsSource = TranslationDirection.containsHangul(trimmedInput)
        let source: Locale.Language? = koreanIsSource ? Locale.Language(identifier: "ko") : nil
        let target = Locale.Language(identifier: koreanIsSource ? appLang : "ko")
        // Gleiches Sprachpaar wie zuletzt? Dann nur neu anstoßen statt neu konfigurieren.
        if var config = configuration, config.source == source, config.target == target {
            config.invalidate()
            configuration = config
        } else {
            configuration = TranslationSession.Configuration(source: source, target: target)
        }
    }

    private func runTranslation(with session: TranslationSession) async {
        let text = trimmedInput
        guard !text.isEmpty else { return }
        isTranslating = true
        defer { isTranslating = false }
        do {
            let response = try await session.translate(text)
            translatedText = response.targetText
            errorText = nil
        } catch {
            translatedText = ""
            errorText = L("translator.error")
        }
    }
}
