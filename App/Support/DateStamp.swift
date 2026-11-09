import Foundation

/// Gecachter Datums-Stamp für Export-Dateinamen (CSV, Backup).
///
/// Der `DateFormatter` ist der teuerste Foundation-Typ; zuvor wurde er pro Export
/// neu alloziert (siehe #143). Hier liegt er als gemeinsamer `static let` – einmal
/// gebaut, von [[VocabCSV]] und [[VocabBackup]] geteilt. Der Stamp ist ein fester
/// Maschinen-String (`yyyy-MM-dd`, `en_US_POSIX`), bewusst *nicht* locale-abhängig,
/// damit Dateinamen stabil und geräteunabhängig sind.
enum DateStamp {
    /// Fester Dateinamen-Formatter: `yyyy-MM-dd`, POSIX-Locale (geräteunabhängig).
    static let file: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// `yyyy-MM-dd`-Stamp für den angegebenen Zeitpunkt (Default: jetzt).
    static func fileStamp(_ date: Date = .now) -> String {
        file.string(from: date)
    }
}
