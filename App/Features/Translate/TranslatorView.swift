import SwiftUI
import Translation

/// DeepL-artiger Übersetzer: Text eingeben, Übersetzung erhalten und beide Seiten
/// vorlesen lassen. Übersetzt on-device via Apples Translation-Framework (iOS 18+),
/// Sprachausgabe über den vorhandenen [[SpeakButton]]. Richtung Koreanisch ↔ App-Sprache,
/// automatisch erkannt via [[TranslationDirection]] mit Tausch-Möglichkeit.
struct TranslatorView: View {
    var body: some View {
        // Kein eigener NavigationStack: aus IchView in dessen Stack gepusht.
        Group {
            if #available(iOS 18.0, *) {
                TranslatorContentView()
            } else {
                ContentUnavailableView(L("translator.unavailable"),
                                       systemImage: "character.bubble",
                                       description: Text(L("translator.unavailable.detail")))
            }
        }
        .paperBackground()
        .navigationTitle(L("translator.title"))
        .navigationBarTitleDisplayMode(.inline)
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
    /// Getrimmte Eingabe, zu der `translatedText` gehört. Weicht sie von der aktuellen
    /// Eingabe ab, ist das Ergebnis veraltet (Eingabe wurde ohne Neuübersetzung geändert)
    /// – dann wird es weder angezeigt noch getauscht.
    @State private var translatedFrom = ""

    /// Löst die Übersetzung aus; wird bei jeder (Neu-)Anforderung gesetzt bzw. invalidiert.
    @State private var configuration: TranslationSession.Configuration?

    /// Fokus des Eingabefelds – zum gezielten Schließen der Tastatur (beim Übersetzen
    /// bzw. über den „Fertig"-Knopf auf der Tastatur), damit das Ergebnis sichtbar wird.
    @FocusState private var inputFocused: Bool

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

    /// Gehört `translatedText` zur aktuellen Eingabe? Nur dann ist das Ergebnis gültig
    /// (anzeigbar, tauschbar).
    private var hasFreshTranslation: Bool {
        !translatedText.isEmpty && trimmedInput == translatedFrom
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
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L("common.done")) { inputFocused = false }
            }
        }
        .translationTask(configuration) { session in
            await runTranslation(with: session)
        }
        .onChange(of: sourceText) {
            // Eingabe geändert → altes Ergebnis passt nicht mehr dazu. Verwerfen, damit
            // keine veraltete Übersetzung angezeigt oder (vertauscht) weitergetragen wird.
            if trimmedInput != translatedFrom {
                translatedText = ""
                errorText = nil
            }
        }
    }

    // MARK: - Kopfleiste mit Sprachen + Tausch

    private var languageBar: some View {
        HStack(spacing: Theme.Spacing.s) {
            languagePill(TranslationDirection.label(for: pair.source))
            Button {
                swap()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.appSubheadline)
                    .foregroundStyle(hasFreshTranslation ? Theme.vermillion : Theme.inkMuted)
                    .frame(width: 34, height: 34)
                    .overlay(Circle().strokeBorder(Theme.hairlineStrong, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(!hasFreshTranslation)
            .accessibilityLabel(L("translator.swap.a11y"))
            languagePill(TranslationDirection.label(for: pair.target))
        }
    }

    private func languagePill(_ text: String) -> some View {
        Text(text)
            .font(.appMono(12))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .overlay(Capsule().strokeBorder(Theme.hairlineStrong, lineWidth: 1))
    }

    // MARK: - Eingabe

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionLabel(L("translator.inputLabel"))
            ZStack(alignment: .topLeading) {
                if sourceText.isEmpty {
                    Text(L("translator.input.placeholder"))
                        .font(.appDisplay(22, weight: .regular))
                        .foregroundStyle(Theme.inkMuted)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $sourceText)
                    .font(.appDisplay(22, weight: .regular))
                    .tint(Theme.vermillion)
                    .frame(minHeight: 110)
                    .scrollContentBackground(.hidden)
                    .focused($inputFocused)
            }
            HStack {
                SpeakButton(text: sourceText, language: pair.sourceTTS)
                Spacer()
                if !sourceText.isEmpty {
                    Button(L("translator.clear")) {
                        sourceText = ""
                        translatedText = ""
                        translatedFrom = ""
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
            } else if !hasFreshTranslation {
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
        guard hasFreshTranslation else { return }
        // Ergebnis wird zur neuen Eingabe; das alte Ergebnis räumt `onChange` weg und die
        // Gegenrichtung wird sofort neu übersetzt (kein manuell durchgereichter Zwischenstand).
        sourceText = translatedText
        translate()
    }

    private func translate() {
        guard !trimmedInput.isEmpty else { return }
        errorText = nil
        inputFocused = false // Tastatur schließen, damit das Ergebnis sichtbar wird
        // Richtung ist stets Koreanisch ↔ App-Sprache: bei Hangul Quelle = Koreanisch,
        // sonst Quelle = App-Sprache. Beide Seiten EXPLIZIT setzen (kein nil/Auto-Erkennen),
        // sonst scheitert Apples Spracherkennung an kurzen Wörtern ("Hallo!") und zeigt den
        // „Sprache konnte nicht erkannt werden"-Dialog – obwohl die Richtung feststeht.
        let koreanIsSource = TranslationDirection.containsHangul(trimmedInput)
        let source = Locale.Language(identifier: koreanIsSource ? "ko" : appLang)
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
            translatedFrom = text // Ergebnis gehört zu genau dieser Eingabe
            errorText = nil
        } catch {
            // Vorhandenes Ergebnis nicht verwerfen: die Ausgabe zeigt bei gesetztem
            // `errorText` ohnehin die Fehlermeldung, und das letzte gültige
            // (translatedText, translatedFrom)-Paar bleibt konsistent erhalten.
            errorText = L("translator.error")
        }
    }
}
