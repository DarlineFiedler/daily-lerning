import Foundation
import SwiftData

/// Erstellt den geteilten SwiftData-Container. Versucht den App-Group-Container
/// (damit die Daten mit der Widget-Extension geteilt werden können) und fällt bei
/// fehlender Berechtigung (z.B. kostenloses Apple-Konto) auf einen lokalen Store zurück.
enum PersistenceController {

    static let schema = Schema([VocabGroup.self, Vocab.self])

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        if inMemory {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: config)
        }

        // 1) Bevorzugt: App-Group-Container (für Widget-Datenaustausch via SwiftData).
        let groupConfig = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier(AppGroup.identifier)
        )
        if let container = try? ModelContainer(for: schema, configurations: groupConfig) {
            return container
        }

        // 2) Fallback: lokaler Standard-Store.
        let localConfig = ModelConfiguration(schema: schema)
        if let container = try? ModelContainer(for: schema, configurations: localConfig) {
            return container
        }

        // 3) Letzter Fallback: In-Memory (verhindert Absturz beim Start).
        let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: memoryConfig)
    }

    /// Vorschau-Container mit Seed-Daten für SwiftUI-Previews.
    @MainActor
    static let preview: ModelContainer = {
        let container = makeContainer(inMemory: true)
        SeedData.insert(into: container.mainContext)
        return container
    }()
}
