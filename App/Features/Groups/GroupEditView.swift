import SwiftData
import SwiftUI

/// Anlegen oder Bearbeiten einer Gruppe (Name + Farbe).
struct GroupEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let group: VocabGroup? // nil = neue Gruppe

    @State private var name: String
    @State private var colorHex: String

    init(group: VocabGroup?) {
        self.group = group
        _name = State(initialValue: group?.name ?? "")
        _colorHex = State(initialValue: group?.colorHex ?? GroupPalette.random)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L("group.name")) {
                    TextField(L("group.namePlaceholder"), text: $name)
                }
                Section(L("group.color")) {
                    ColorGridPicker(selection: $colorHex)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(group == nil ? L("group.new") : L("group.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("common.save"), action: save)
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private func save() {
        if let group {
            group.name = trimmedName
            group.colorHex = colorHex
        } else {
            let count = (try? context.fetchCount(FetchDescriptor<VocabGroup>())) ?? 0
            let newGroup = VocabGroup(name: trimmedName, colorHex: colorHex, sortOrder: count)
            context.insert(newGroup)
        }
        context.saveOrLog()
        dismiss()
    }
}
