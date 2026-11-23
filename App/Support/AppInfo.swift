import Foundation

/// Statisch gecachte App-Metadaten aus dem Bundle. `version` wird einmal aus
/// `Info.plist` gelesen statt bei jedem Zugriff (z.B. im Einstellungs-Screen) neu.
enum AppInfo {
    /// Anzeige-Version im Format „<MarketingVersion> (<Build>)", z.B. „3.5.0 (57)".
    static let version: String = {
        let info = Bundle.main.infoDictionary
        let marketing = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(marketing) (\(build))"
    }()
}
