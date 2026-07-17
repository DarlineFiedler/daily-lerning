import Foundation

/// Ein mitgeliefertes Vokabel-„Paket": eine CSV-Datei aus dem `WordPacks/`-Ordner
/// des App-Bundles. Der Dateiname (ohne Endung) dient als Gruppenname beim Import.
struct WordPack: Identifiable {
    let id: String        // Dateiname ohne Endung (z.B. "berufe")
    let name: String      // Gruppenname (Dateiname, erster Buchstabe groß)
    let rows: [VocabCSV.Row]

    var count: Int { rows.count }

    /// Lädt alle CSV-Pakete aus dem gebündelten `WordPacks/`-Ordner, überspringt leere
    /// Dateien und sortiert alphabetisch nach Name. Nutzt den bestehenden CSV-Parser.
    static func loadBundled() -> [WordPack] {
        let urls = Bundle.main.urls(forResourcesWithExtension: "csv", subdirectory: "WordPacks") ?? []
        return urls.compactMap { url -> WordPack? in
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            let rows = VocabCSV.parse(content)
            guard !rows.isEmpty else { return nil }   // leere Pakete ausblenden
            let base = url.deletingPathExtension().lastPathComponent
            return WordPack(id: base, name: base.capitalizedFirst, rows: rows)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

private extension String {
    /// „berufe" → „Berufe" (nur der erste Buchstabe wird großgeschrieben).
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
