import SwiftUI
import UIKit

/// Dünner SwiftUI-Wrapper um `UIActivityViewController`, um eine Datei (z.B. die
/// JSON-Sicherung) per System-Share-Sheet zu teilen – etwa „In Dateien sichern"
/// oder nach iCloud Drive. Wird via `.sheet(item:)` präsentiert.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
