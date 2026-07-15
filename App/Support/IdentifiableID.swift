import Foundation

/// Kleiner Wrapper, um eine UUID in `.sheet(item:)` verwenden zu können.
struct IdentifiableID: Identifiable, Hashable {
    let id: UUID
}
