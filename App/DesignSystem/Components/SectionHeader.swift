import SwiftUI

/// Abschnitts-Überschrift im verspielten Stil (fett, gerundet, optional mit Aktion rechts).
struct SectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    init(_ title: String, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.appTitle3)
                .foregroundStyle(.primary)
            Spacer()
            trailing()
        }
    }
}
