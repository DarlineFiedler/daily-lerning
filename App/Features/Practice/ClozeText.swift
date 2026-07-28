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

    /// Der Beispielsatz mit dem gesuchten Wort als Lücke. Kommt das Wort wörtlich vor,
    /// wird es (case-insensitiv) durch die Lücke ersetzt; sonst – z.B. bei gebeugten
    /// Formen – bleibt der ganze Satz als Kontext stehen (das Wort wird trotzdem getippt).
    static func blanked(example: String, word: String) -> String {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedWord.isEmpty,
              let range = example.range(of: trimmedWord, options: .caseInsensitive)
        else { return example }
        return example.replacingCharacters(in: range, with: blank)
    }
}
