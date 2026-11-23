import Foundation

/// Reine (testbare) Logik für den Lückentext-Modus: prüft, ob ein Wort einen
/// brauchbaren Beispielsatz hat, und erzeugt den Satz mit ausgeblendeter Lücke.
///
/// Das Wort wird nicht als bloßer Substring gesucht, sondern pro **Wort-Token** des
/// Satzes (an Leerzeichen getrennt, Satzzeichen am Rand abgeschnitten). Ein Token passt,
/// wenn es exakt das Wort ist oder das Wort plus eine angehängte Partikel aus
/// `particles` (Issue #133). So wird `가` in `가방` nicht zur Lücke, und bei `학교에`
/// verschwindet das ganze Token – die Partikel verrät keine grammatische Info.
enum ClozeText {
    /// Sichtbare Lücke im Beispielsatz.
    static let blank = "＿＿＿"

    /// Partikel (inkl. häufiger Kombinationen), die nach einem Wort mit Schlusskonsonant
    /// (Batchim) stehen – z.B. `학교` → nein, `책을` → ja.
    static let particlesAfterConsonant: Set<String> = [
        "이", "은", "을", "과", "으로", "이나", "이랑", "이에요", "이야", "이다", "이고",
        "으로는", "으로도", "이라도", "이라고", "입니다", "이었어요"
    ]

    /// Partikel, die nach einem Wort ohne Schlusskonsonant stehen – z.B. `학교가`.
    static let particlesAfterVowel: Set<String> = [
        "가", "는", "를", "와", "로", "나", "랑", "예요", "야", "다", "고",
        "로는", "로도", "라도", "라고", "입니다", "였어요"
    ]

    /// Partikel, deren Form nicht vom Auslaut abhängt.
    static let particlesAny: Set<String> = [
        "에", "에서", "에게", "한테", "께", "의", "도", "만", "하고", "부터", "까지",
        "보다", "처럼", "같이", "마다", "요", "께서", "한테서", "에게서",
        "에는", "에도", "에서는", "에서도", "에게는", "한테는", "까지는", "부터는",
        "만은", "도요", "에요"
    ]

    /// Satzzeichen, die am Anfang/Ende eines Tokens abgeschnitten werden.
    private static let punctuation = CharacterSet.punctuationCharacters
        .union(.symbols)
        .union(CharacterSet(charactersIn: "~…"))

    /// Der Beispielsatz, sofern gesetzt und nicht leer – sonst `nil`. Nur Wörter mit
    /// brauchbarem Beispiel können im Lückentext-Modus abgefragt werden.
    static func usableExample(for vocab: Vocab) -> String? {
        guard let example = vocab.example else { return nil }
        let trimmed = example.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Ob ein Wort im Lückentext abgefragt werden kann: es braucht einen brauchbaren
    /// Beispielsatz, in dem das Wort als eigenes Token (ggf. mit Partikel) vorkommt. Fehlt
    /// es (z.B. nur eine gebeugte Form oder als Teil eines anderen Wortes), würde die
    /// „Lücke" die Antwort zeigen bzw. den Satz verfälschen – solche Wörter werden daher
    /// gar nicht erst im Lückentext abgefragt.
    static func canCloze(_ vocab: Vocab) -> Bool {
        guard let example = usableExample(for: vocab) else { return false }
        let word = vocab.word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return false }
        return tokens(of: example).contains { matches(core: $0.core, word: word) }
    }

    /// Der Beispielsatz mit dem gesuchten Wort als Lücke. Jedes passende Token (Wort
    /// oder Wort+Partikel) wird komplett ersetzt, Satzzeichen und Leerraum bleiben. Kommt
    /// das Wort nicht vor, bleibt der Satz unverändert (durch `canCloze` gefiltert; nur defensiv).
    static func blanked(example: String, word: String) -> String {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedWord.isEmpty else { return example }
        var result = ""
        var cursor = example.startIndex
        for token in tokens(of: example) where matches(core: token.core, word: trimmedWord) {
            result += example[cursor ..< token.range.lowerBound]
            result += blank
            cursor = token.range.upperBound
        }
        result += example[cursor...]
        return result
    }

    // MARK: - Intern

    /// Ein Wort-Token: Kern ohne Rand-Satzzeichen und dessen Lage im Satz.
    private struct Token {
        let core: String
        let range: Range<String.Index>
    }

    /// Zerlegt den Satz an Leerraum und schneidet Rand-Satzzeichen ab.
    private static func tokens(of sentence: String) -> [Token] {
        var result: [Token] = []
        var index = sentence.startIndex
        while index < sentence.endIndex {
            guard !sentence[index].isWhitespace else {
                index = sentence.index(after: index)
                continue
            }
            var end = index
            while end < sentence.endIndex, !sentence[end].isWhitespace {
                end = sentence.index(after: end)
            }
            if let core = trimmedPunctuation(sentence, in: index ..< end) {
                result.append(Token(core: String(sentence[core]), range: core))
            }
            index = end
        }
        return result
    }

    /// Bereich ohne führende/abschließende Satzzeichen – `nil`, wenn nichts übrig bleibt.
    private static func trimmedPunctuation(_ text: String, in range: Range<String.Index>) -> Range<String.Index>? {
        var lower = range.lowerBound
        var upper = range.upperBound
        while lower < upper, isPunctuation(text[lower]) {
            lower = text.index(after: lower)
        }
        while upper > lower, isPunctuation(text[text.index(before: upper)]) {
            upper = text.index(before: upper)
        }
        return lower < upper ? lower ..< upper : nil
    }

    private static func isPunctuation(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { punctuation.contains($0) }
    }

    /// Ob der Token-Kern das Wort ist – exakt oder mit passender angehängter Partikel.
    static func matches(core: String, word: String) -> Bool {
        let core = core.lowercased()
        let word = word.lowercased()
        guard core.hasPrefix(word) else { return false }
        let suffix = String(core.dropFirst(word.count))
        if suffix.isEmpty || particlesAny.contains(suffix) { return true }
        switch hasFinalConsonant(word) {
        case true?:
            // Auf ㄹ endende Wörter nehmen die Vokal-Form von (으)로: 물로, 서울로.
            if endsWithRieul(word) {
                if suffix.hasPrefix("으로") { return false }
                if suffix.hasPrefix("로") { return particlesAfterVowel.contains(suffix) }
            }
            return particlesAfterConsonant.contains(suffix)
        case false?: return particlesAfterVowel.contains(suffix)
        case nil:
            // Kein Hangul-Auslaut (z.B. lateinisches Wort): beide Formen zulassen.
            return particlesAfterConsonant.contains(suffix) || particlesAfterVowel.contains(suffix)
        }
    }

    /// Batchim des letzten Zeichens: `true`/`false` für Hangul-Silben, sonst `nil`.
    private static func hasFinalConsonant(_ word: String) -> Bool? {
        guard let scalar = word.unicodeScalars.last,
              (0xAC00 ... 0xD7A3).contains(scalar.value) else { return nil }
        return (scalar.value - 0xAC00) % 28 != 0
    }

    /// Ob die letzte Hangul-Silbe auf ㄹ (Batchim-Index 8) endet.
    private static func endsWithRieul(_ word: String) -> Bool {
        guard let scalar = word.unicodeScalars.last,
              (0xAC00 ... 0xD7A3).contains(scalar.value) else { return false }
        return (scalar.value - 0xAC00) % 28 == 8
    }
}
