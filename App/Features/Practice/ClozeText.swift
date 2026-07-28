import Foundation

/// Reine (testbare) Logik für den Lückentext-Modus: prüft, ob ein Wort einen
/// brauchbaren Beispielsatz hat, und erzeugt den Satz mit ausgeblendeter Lücke.
enum ClozeText {
    /// Sichtbare Lücke im Beispielsatz.
    static let blank = "＿＿＿"

    /// Der Beispielsatz, sofern gesetzt und nicht leer – sonst `nil`. Nur Wörter mit
    /// brauchbarem Beispiel können im Lückentext-Modus abgefragt werden.
    static func usableExample(for vocab: Vocab) -> String? {
        guard let example = vocab.example else { return nil }
        let trimmed = example.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Ob ein Wort im Lückentext abgefragt werden kann: es braucht einen brauchbaren
    /// Beispielsatz, in dem das Wort auch wörtlich vorkommt. Fehlt es (z.B. nur eine
    /// gebeugte Form steht im Satz), würde die „Lücke" die Antwort offen zeigen statt sie
    /// zu verbergen – solche Wörter werden daher gar nicht erst im Lückentext abgefragt.
    static func canCloze(_ vocab: Vocab) -> Bool {
        guard let example = usableExample(for: vocab) else { return false }
        let word = vocab.word.trimmingCharacters(in: .whitespacesAndNewlines)
        return !word.isEmpty && example.range(of: word, options: .caseInsensitive) != nil
    }

    /// Der Beispielsatz mit dem gesuchten Wort als Lücke. Alle (case-insensitiven)
    /// Vorkommen werden ersetzt, damit kein Treffer die Antwort verrät. Kommt das Wort
    /// nicht vor, bleibt der Satz unverändert (durch `canCloze` gefiltert; nur defensiv).
    static func blanked(example: String, word: String) -> String {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedWord.isEmpty else { return example }
        return example.replacingOccurrences(of: trimmedWord, with: blank, options: [.caseInsensitive])
    }
}
