import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Importiert mehrere Vokabeln auf einmal – per eingefügtem Text oder Datei
/// (.csv/.txt). Format: eine Zeile pro Vokabel, `Wort ; Bedeutung ; Beispiel`.
struct VocabImportView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \VocabGroup.sortOrder) private var groups: [VocabGroup]

    enum Target: Hashable {
        case existing(VocabGroup)
        case new
    }

    @State private var text = ""
    @State private var target: Target = .new
    @State private var newGroupName = ""
    @State private var showFileImporter = false
    @State private var importError = false
    /// Aktiver Niveau-Filter (`nil` = alle Niveaus importieren). Nur relevant, wenn die
    /// eingefügten Daten überhaupt eine TOPIK-Spalte enthalten (siehe `hasLevels`).
    @State private var levelFilter: TopikLevel?

    private var parsedRows: [VocabCSV.Row] { VocabCSV.parse(text) }

    /// Enthält der eingefügte Text mindestens eine eingestufte Zeile? Nur dann blenden
    /// wir den Niveau-Filter ein (alte Pakete ohne Spalte bleiben unverändert).
    private var hasLevels: Bool { parsedRows.contains { $0.topik != nil } }

    /// Die tatsächlich zu importierenden Zeilen nach Anwenden des Niveau-Filters.
    private var filteredRows: [VocabCSV.Row] {
        guard let levelFilter else { return parsedRows }
        return parsedRows.filter { $0.topik == levelFilter }
    }

    private var canImport: Bool {
        guard !filteredRows.isEmpty else { return false }
        switch target {
        case .existing: return true
        case .new: return !newGroupName.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(L("vocab.group"), selection: $target) {
                        ForEach(groups) { group in
                            Text(group.name).tag(Target.existing(group))
                        }
                        Text(L("import.newGroup")).tag(Target.new)
                    }
                    if target == .new {
                        TextField(L("group.namePlaceholder"), text: $newGroupName)
                    }
                } header: {
                    Text(L("import.target"))
                }

                Section {
                    TextEditor(text: $text)
                        .frame(minHeight: 140)
                        .font(.appBody)
                    Button {
                        showFileImporter = true
                    } label: {
                        Label(L("import.fromFile"), systemImage: "doc.badge.plus")
                    }
                } header: {
                    Text(L("import.paste"))
                } footer: {
                    Text(L("import.formatHint"))
                }

                if hasLevels {
                    Section {
                        Picker(L("import.levelFilter"), selection: $levelFilter) {
                            Text(L("import.levelAll")).tag(TopikLevel?.none)
                            ForEach(TopikLevel.allCases) { level in
                                Text(L(level.titleKey)).tag(TopikLevel?.some(level))
                            }
                        }
                        .pickerStyle(.segmented)
                    } header: {
                        Text(L("import.levelSection"))
                    }
                }

                if !text.isEmpty {
                    Section {
                        Text(L("import.preview", filteredRows.count))
                            .foregroundStyle(filteredRows.isEmpty ? .secondary : .primary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(L("settings.data.import"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("import.action"), action: performImport).disabled(!canImport)
                }
            }
            .onAppear {
                if case .new = target, let first = groups.first { target = .existing(first) }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText, .text],
                allowsMultipleSelection: false
            ) { result in
                loadFile(result)
            }
            .alert(L("import.error"), isPresented: $importError) {
                Button(L("common.done"), role: .cancel) {}
            }
        }
    }

    private func loadFile(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        let needsStop = url.startAccessingSecurityScopedResource()
        defer { if needsStop { url.stopAccessingSecurityScopedResource() } }
        if let content = try? String(contentsOf: url, encoding: .utf8) {
            text = content
        } else {
            importError = true
        }
    }

    private func performImport() {
        let rows = filteredRows
        guard !rows.isEmpty else { return }

        let groupName: String
        switch target {
        case .existing(let g): groupName = g.name
        case .new: groupName = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        VocabImporter.importRows(rows, intoGroupNamed: groupName, context: context, existingGroups: groups)
        context.saveOrLog()
        WidgetSnapshotWriter.refresh(context: context)
        BadgeUpdater.refresh(context: context)
        dismiss()
    }
}
