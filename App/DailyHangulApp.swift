import SwiftUI
import SwiftData

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
