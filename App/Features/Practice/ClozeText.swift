import Foundation

/// Reine (testbare) Logik für den Lückentext-Modus: prüft, ob ein Wort einen
/// brauchbaren Beispielsatz hat, und erzeugt den Satz mit ausgeblendeter Lücke.
///
/// Das Wort wird nicht als bloßer Substring gesucht, sondern über **Wort-Tokens**
/// (Buchstaben-/Ziffernfolgen zwischen Leerraum und Satzzeichen, Issue #133). Ein
/// Eintrag passt auf eine Folge aufeinanderfolgender Tokens: alle bis auf das letzte
/// müssen exakt gleich sein, das letzte darf zusätzlich eine angehängte Partikel-Kette
/// tragen (`학교에서는`, `친구들이`). So wird `가` in `가방` nicht zur Lücke, und bei
/// `학교에` verschwindet das ganze Token – die Partikel verrät keine grammatische Info.
///
/// Grenzen der Heuristik: gebeugte Verben werden nicht erkannt (solche Wörter fallen
/// über `canCloze` aus dem Modus), und ein kurzes Wort plus eine Silbe, die zufällig
/// eine Partikel ist, bleibt mehrdeutig (`도` + `로` vs. `도로`).
enum ClozeText {
    /// Sichtbare Lücke im Beispielsatz.
    static let blank = "＿＿＿"

    /// Partikel nach einem Auslaut **mit** Schlusskonsonant (Batchim) – `책을`, `집으로`.
    static let particlesAfterConsonant: Set<String> = [
        "이", "은", "을", "과", "으로", "이나", "이랑", "이라도", "이나마", "이며"
    ]

    /// Partikel nach einem Auslaut **ohne** Schlusskonsonant – `학교가`, `학교로`.
    /// Bewusst ohne ein-silbige Endungen wie `다`/`고`/`야`/`나`/`랑`, die eher Teil
    /// eines anderen Wortes sind (`바다`, `차고`, `사랑`) als eine Partikel.
    static let particlesAfterVowel: Set<String> = [
        "가", "는", "를", "와", "로", "라도", "나마", "며"
    ]

    /// Partikel, deren Form nicht vom Auslaut abhängt.
    static let particlesAny: Set<String> = [
        "에", "에서", "에게", "한테", "께", "께서", "의", "도", "만", "하고", "부터", "까지",
        "보다", "처럼", "같이", "마다", "만큼", "밖에", "뿐", "조차", "마저", "에게서", "한테서"
    ]

    /// Kopula-/Satzendungen, die nur am **Ende** einer Kette stehen dürfen.
    static let copulaAfterConsonant: Set<String> = [
        "이에요", "이야", "이다", "이고", "이지만", "이라고", "이었어요", "이었다"
    ]
    static let copulaAfterVowel: Set<String> = [
        "예요", "였어요", "였다", "라고", "지만"
    ]
    static let copulaAny: Set<String> = ["입니다", "입니까", "인데"]

    /// Höchstzahl der Elemente einer Endungs-Kette (Plural `들` + Partikel + Kopula).
    private static let maxChainLength = 3

    /// Zeichen, an denen Tokens getrennt werden (neben Leerraum).
    private static let separators = CharacterSet.punctuationCharacters
        .union(.symbols)
        .union(CharacterSet(charactersIn: "~…·"))

    /// Der Beispielsatz, sofern gesetzt und nicht leer – sonst `nil`. Nur Wörter mit
    /// brauchbarem Beispiel können im Lückentext-Modus abgefragt werden.
    static func usableExample(for vocab: Vocab) -> String? {
        guard let example = vocab.example else { return nil }
        let trimmed = example.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Ob ein Wort im Lückentext abgefragt werden kann: es braucht einen brauchbaren
    /// Beispielsatz, in dem das Wort als eigene Token-Folge (ggf. mit Partikel) vorkommt.
    /// Fehlt es (z.B. nur eine gebeugte Form oder als Teil eines anderen Wortes), würde
    /// die „Lücke" die Antwort zeigen bzw. den Satz verfälschen – solche Wörter werden
    /// daher gar nicht erst im Lückentext abgefragt.
    static func canCloze(_ vocab: Vocab) -> Bool {
        guard let example = usableExample(for: vocab) else { return false }
        return !matchRanges(in: normalized(example), word: vocab.word).isEmpty
    }

    /// Der Beispielsatz mit dem gesuchten Wort als Lücke. Jede passende Token-Folge wird
    /// komplett (inkl. Partikel) ersetzt, Satzzeichen und Leerraum drumherum bleiben.
    /// Kommt das Wort nicht vor, bleibt der Satz unverändert (durch `canCloze`
    /// gefiltert; nur defensiv).
    static func blanked(example: String, word: String) -> String {
        let sentence = normalized(example)
        let ranges = matchRanges(in: sentence, word: word)
        guard !ranges.isEmpty else { return example }
        var result = ""
        var cursor = sentence.startIndex
        for range in ranges {
            result += sentence[cursor ..< range.lowerBound]
            result += blank
            cursor = range.upperBound
        }
        result += sentence[cursor...]
        return result
    }

    /// Ob ein einzelner Token-Kern das Wort ist – exakt oder mit passender Endungs-Kette.
    static func matches(core: String, word: String) -> Bool {
        let core = normalized(core)
        let word = normalized(word)
        guard !word.isEmpty,
              let prefix = core.range(of: word, options: [.anchored, .caseInsensitive]) else { return false }
        return isEndingChain(String(core[prefix.upperBound...]), after: word, depth: 0)
    }

    // MARK: - Intern

    /// Bereiche im Satz, die das (ggf. mehrteilige) Wort abdecken – ohne Überlappung.
    private static func matchRanges(in sentence: String, word: String) -> [Range<String.Index>] {
        let normalizedWord = normalized(word)
        let parts = tokenRanges(of: normalizedWord).map { String(normalizedWord[$0]) }
        guard let lastPart = parts.last else { return [] }
        let tokens = tokenRanges(of: sentence)
        guard tokens.count >= parts.count else { return [] }

        var result: [Range<String.Index>] = []
        var index = 0
        while index + parts.count <= tokens.count {
            let window = tokens[index ..< index + parts.count]
            let leadingMatch = zip(window.dropLast(), parts.dropLast()).allSatisfy { range, part in
                sentence[range].compare(part, options: .caseInsensitive) == .orderedSame
            }
            if let last = window.last, leadingMatch, matches(core: String(sentence[last]), word: lastPart),
               let first = window.first {
                result.append(first.lowerBound ..< last.upperBound)
                index += parts.count
            } else {
                index += 1
            }
        }
        return result
    }

    /// Bereiche der Wort-Tokens: maximale Folgen ohne Leerraum und ohne Satzzeichen.
    private static func tokenRanges(of text: String) -> [Range<String.Index>] {
        var result: [Range<String.Index>] = []
        var start: String.Index?
        var index = text.startIndex
        while index < text.endIndex {
            if isSeparator(text[index]) {
                if let tokenStart = start { result.append(tokenStart ..< index) }
                start = nil
            } else if start == nil {
                start = index
            }
            index = text.index(after: index)
        }
        if let tokenStart = start { result.append(tokenStart ..< text.endIndex) }
        return result
    }

    private static func isSeparator(_ character: Character) -> Bool {
        character.isWhitespace || character.unicodeScalars.allSatisfy { separators.contains($0) }
    }

    /// Ob `suffix` (nach `preceding`) leer ist oder sich in eine Kette aus optionalem
    /// Plural `들`, Partikeln und einer abschließenden Kopula-Endung zerlegen lässt. Jedes
    /// Element muss zum Auslaut des davorstehenden Textes passen.
    private static func isEndingChain(_ suffix: String, after preceding: String, depth: Int) -> Bool {
        if suffix.isEmpty { return true }
        guard depth < maxChainLength else { return false }
        for length in stride(from: suffix.count, through: 1, by: -1) {
            let head = String(suffix.prefix(length))
            let rest = String(suffix.dropFirst(length))
            if rest.isEmpty, isCopula(head, after: preceding) { return true }
            let allowed = (head == "들" && depth == 0) || isParticle(head, after: preceding)
            if allowed, isEndingChain(rest, after: preceding + head, depth: depth + 1) { return true }
        }
        return false
    }

    private static func isParticle(_ candidate: String, after preceding: String) -> Bool {
        fits(candidate, after: preceding, any: particlesAny,
             consonant: particlesAfterConsonant, vowel: particlesAfterVowel)
    }

    private static func isCopula(_ candidate: String, after preceding: String) -> Bool {
        fits(candidate, after: preceding, any: copulaAny,
             consonant: copulaAfterConsonant, vowel: copulaAfterVowel)
    }

    /// Prüft ein Endungs-Element gegen die passende Liste je nach Auslaut.
    private static func fits(_ candidate: String, after preceding: String,
                             any: Set<String>, consonant: Set<String>, vowel: Set<String>) -> Bool {
        if any.contains(candidate) { return true }
        switch finalSound(of: preceding) {
        case .consonant: return consonant.contains(candidate)
        case .vowel: return vowel.contains(candidate)
        case .rieul:
            // Auf ㄹ endende Wörter nehmen die Vokal-Form von (으)로: 물로, 서울로.
            if candidate.hasPrefix("으로") { return false }
            return candidate.hasPrefix("로") ? vowel.contains(candidate) : consonant.contains(candidate)
        case .other:
            // Kein Hangul-Auslaut (z.B. lateinisches Wort): beide Formen zulassen.
            return consonant.contains(candidate) || vowel.contains(candidate)
        }
    }

    private enum FinalSound { case vowel, consonant, rieul, other }

    /// Auslaut der letzten Hangul-Silbe (Text ist NFC-normalisiert).
    private static func finalSound(of text: String) -> FinalSound {
        guard let scalar = text.unicodeScalars.last,
              (0xAC00 ... 0xD7A3).contains(scalar.value) else { return .other }
        switch (scalar.value - 0xAC00) % 28 {
        case 0: return .vowel
        case 8: return .rieul
        default: return .consonant
        }
    }

    /// Zerlegtes (NFD) Hangul – etwa aus eingefügtem/importiertem Text – zu Silben
    /// zusammensetzen, damit Vergleich und Auslaut-Bestimmung funktionieren.
    private static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).precomposedStringWithCanonicalMapping
    }
}
