import SwiftUI

/// Auswahl einer Gruppenfarbe: Palette-Raster + freier ColorPicker.
struct ColorGridPicker: View {
    @Binding var selection: String

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    private var customColor: Binding<Color> {
        Binding(
            get: { Color(hex: selection) },
            set: { selection = $0.hexString }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(GroupPalette.colors, id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(height: 32)
                        .overlay {
                            if hex.caseInsensitiveCompare(selection) == .orderedSame {
                                Circle().strokeBorder(.primary, lineWidth: 3)
                            }
                        }
                        .onTapGesture { selection = hex }
                }
            }

            ColorPicker(selection: customColor, supportsOpacity: false) {
                Text(L("group.color"))
            }
        }
        .padding(.vertical, 4)
    }
}
