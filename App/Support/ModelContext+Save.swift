import Foundation
import OSLog
import SwiftData

private let persistenceLog = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.darlinefiedler.DailyHangul",
    category: "persistence"
)

extension ModelContext {
    /// Speichert den Kontext und protokolliert Fehler, statt sie stumm zu verwerfen
    /// (wie es `try? save()` tut). In Debug-Builds schlägt ein Fehler zusätzlich auf,
    /// damit er beim Entwickeln nicht unbemerkt bleibt.
    func saveOrLog(_ site: StaticString = #function) {
        guard hasChanges else { return }
        do {
            try save()
        } catch {
            persistenceLog.error("SwiftData save failed at \(site, privacy: .public): \(error.localizedDescription, privacy: .public)")
            assertionFailure("SwiftData save failed: \(error)")
        }
    }
}
