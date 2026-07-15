import SwiftUI

/// Kleiner farbiger Statuspunkt.
struct StatusDot: View {
    let status: LearningStatus
    var size: CGFloat = 10
    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: size, height: size)
    }
}

/// Status-Label mit Icon + Text.
struct StatusBadge: View {
    let status: LearningStatus
    var body: some View {
        Label(L(status.titleKey), systemImage: status.systemImage)
            .font(.caption)
            .foregroundStyle(status.color)
    }
}

/// Farbpunkt einer Gruppe.
struct GroupColorDot: View {
    let colorHex: String
    var size: CGFloat = 14
    var body: some View {
        Circle()
            .fill(Color(hex: colorHex))
            .frame(width: size, height: size)
    }
}
