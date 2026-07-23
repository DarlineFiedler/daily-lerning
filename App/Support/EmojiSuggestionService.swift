import Foundation

/// Schlägt anhand der deutschen Bedeutung einer Vokabel automatisch ein Emoji als
/// visuelle Merkhilfe vor. Bewusst rein lokal/statisch – keine externen Abhängigkeiten,
/// kein Netzwerk, kein ML: eine von Hand kuratierte Stichwort→Emoji-Tabelle, passend zu
/// den mitgelieferten Themen-Wortpaketen (`WordPacks/`). Kein Treffer ⇒ `nil` (leeres
/// Feld, kein Fehlerzustand); der Nutzer kann jederzeit manuell ein Emoji setzen.
enum EmojiSuggestionService {

    /// Liefert ein Vorschlags-Emoji für die gegebene Bedeutung oder `nil`, wenn nichts passt.
    /// Das Matching ist case-insensitiv und tolerant gegenüber Mehrfachbedeutungen
    /// (z. B. „Reis, Mahlzeit"): geprüft wird in dieser Reihenfolge – (1) die ganze
    /// normalisierte Bedeutung, (2) die per Komma/Semikolon/Schrägstrich getrennten
    /// Teilbedeutungen, (3) einzelne Wörter darin. Der erste Treffer gewinnt, damit das
    /// Ergebnis auch bei Mehrdeutigkeiten deterministisch (links-nach-rechts) ist.
    static func suggest(for meaning: String) -> String? {
        let normalized = normalize(meaning)
        guard !normalized.isEmpty else { return nil }

        // 1) Ganze Bedeutung als Schlüssel (z. B. "koreanisches essen").
        if let hit = table[normalized] { return hit }

        // 2) Durch Trenner separierte Teilbedeutungen (Synonyme).
        let parts = normalized
            .split(whereSeparator: { ",;/".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        for part in parts where table[part] != nil {
            return table[part]
        }

        // 3) Einzelne Wörter über alle Teile (für Mehrwort-Bedeutungen).
        for part in parts {
            for token in part.split(separator: " ") {
                if let hit = table[String(token)] { return hit }
            }
        }
        return nil
    }

    /// Normalisierung: Kleinbuchstaben + zusammengefasste Whitespaces. Diakritika bleiben
    /// erhalten, weil deutsche Umlaute bedeutungstragend sind (z. B. „schön"/„schon").
    private static func normalize(_ s: String) -> String {
        s.lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    /// Kuratierte Stichwort→Emoji-Tabelle. Schlüssel sind kleingeschrieben und decken die
    /// Themen der gebündelten Wortpakete ab (Tiere, Essen, Trinken, Familie, Kleidung …)
    /// plus häufige Alltagsvokabeln. Erweiterbar – ein fehlender Eintrag ist kein Fehler,
    /// er führt schlicht zu keinem Vorschlag.
    private static let table: [String: String] = [
        // Tiere
        "tier": "🐾", "tiere": "🐾", "katze": "🐱", "hund": "🐶", "welpe": "🐶",
        "bär": "🐻", "hase": "🐰", "kaninchen": "🐰", "vogel": "🐦", "fisch": "🐟",
        "pferd": "🐴", "kuh": "🐮", "rind": "🐮", "schwein": "🐷", "maus": "🐭",
        "tiger": "🐯", "löwe": "🦁", "elefant": "🐘", "affe": "🐵", "schlange": "🐍",
        "frosch": "🐸", "schaf": "🐑", "ziege": "🐐", "wolf": "🐺", "fuchs": "🦊",
        "ente": "🦆", "biene": "🐝", "schmetterling": "🦋", "spinne": "🕷️", "pinguin": "🐧",

        // Essen
        "essen": "🍽️", "mahlzeit": "🍚", "apfel": "🍎", "brot": "🍞", "reis": "🍚",
        "kimchi": "🥬", "fleisch": "🍖", "banane": "🍌", "orange": "🍊", "huhn": "🍗",
        "hühnchen": "🍗", "mango": "🥭", "ei": "🥚", "eier": "🥚", "käse": "🧀",
        "pizza": "🍕", "nudeln": "🍜", "ramyeon": "🍜", "suppe": "🍲", "eintopf": "🍲",
        "kuchen": "🍰", "schokolade": "🍫", "erdbeere": "🍓", "traube": "🍇", "tomate": "🍅",
        "karotte": "🥕", "möhre": "🥕", "gemüse": "🥗", "salat": "🥗", "hamburger": "🍔",
        "pommes": "🍟", "sushi": "🍣", "birne": "🍐", "zitrone": "🍋", "wassermelone": "🍉",

        // Trinken
        "kaffee": "☕", "saft": "🧃", "wasser": "💧", "alkohol": "🍺", "tee": "🍵",
        "grüntee": "🍵", "schwarztee": "🍵", "bier": "🍺", "milch": "🥛", "wein": "🍷",
        "getränk": "🥤", "soju": "🍶", "schnaps": "🍶",

        // Familie & Personen
        "familie": "👨‍👩‍👧‍👦", "mama": "👩", "mutter": "👩", "papa": "👨", "vater": "👨",
        "baby": "👶", "kind": "🧒", "bruder": "👦", "schwester": "👧", "geschwister": "🧒",
        "oma": "👵", "großmutter": "👵", "opa": "👴", "großvater": "👴", "sohn": "👦",
        "tochter": "👧", "mann": "👨", "frau": "👩", "freund": "🧑", "freundin": "🧑",
        "person": "🧑", "lehrer": "🧑‍🏫", "lehrerin": "🧑‍🏫", "arzt": "🧑‍⚕️", "ärztin": "🧑‍⚕️",

        // Kleidung
        "rock": "👗", "hose": "👖", "t-shirt": "👕", "hemd": "👕", "kleid": "👗",
        "jacke": "🧥", "mantel": "🧥", "mütze": "🧢", "hut": "🎩", "socken": "🧦",
        "handschuhe": "🧤", "brille": "👓", "tasche": "👜", "schuhe": "👟", "schuh": "👟",

        // Körper
        "hand": "✋", "auge": "👁️", "augen": "👁️", "herz": "❤️", "nase": "👃",
        "mund": "👄", "ohr": "👂", "fuß": "🦶", "bein": "🦵", "zahn": "🦷", "kopf": "🧠",

        // Natur, Orte & Alltag
        "haus": "🏠", "zuhause": "🏠", "schule": "🏫", "auto": "🚗", "baum": "🌳",
        "blume": "🌸", "sonne": "☀️", "mond": "🌙", "stern": "⭐", "regen": "🌧️",
        "schnee": "❄️", "berg": "⛰️", "meer": "🌊", "buch": "📖", "geld": "💰",
        "telefon": "📱", "handy": "📱", "computer": "💻", "uhr": "🕐", "zeit": "🕐",
        "stadt": "🏙️", "land": "🌍", "welt": "🌍", "feuer": "🔥", "wind": "💨",

        // Verben & Zustände (häufige Bedeutungen)
        "gehen": "🚶", "laufen": "🏃", "trinken": "🥤", "schlafen": "😴",
        "lernen": "📚", "lesen": "📖", "schreiben": "✍️", "sehen": "👀", "hören": "👂",
        "sprechen": "🗣️", "lachen": "😄", "weinen": "😢", "lieben": "❤️", "arbeiten": "💼"
    ]
}
