import SwiftData
import SwiftUI

@main
struct DailyHangulApp: App {
    let container = PersistenceController.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
        }
    }
}
