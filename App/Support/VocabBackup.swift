import Foundation
import SwiftData

/// Vollständige, verlustfreie Sicherung aller Gruppen und Vokabeln als JSON.
/// Anders als der CSV-Export (`VocabCSV`, nur Wort/Bedeutung/Beispiel) enthält
/// die Sicherung ALLE Modellfelder inkl. Lernstand, SRS-Fälligkeit, Widget-Flags,
/// Gruppenfarbe/-reihenfolge und stabiler `id`s. Wird sowohl fürs manuelle
/// Backup/Wiederherstellen (SettingsView) als auch für die einmalige
/// Store-Migration ([[StoreMigration]]) verwendet.
struct VocabBackup: Codable {
    var schemaVersion: Int = 1
    var exportedAt: Date = .now
    var groups: [GroupDTO]
    var vocabs: [VocabDTO]

    struct GroupDTO: Codable {
        var id: UUID
        var name: String
        var colorHex: String
        var sortOrder: Int
        var createdAt: Date
    }

    struct VocabDTO: Codable {
        var id: UUID
        var word: String
        var meaning: String
        var example: String?
        var statusRaw: Int
        var successCounter: Int
        var includeInWidget: Bool
        var timesPracticed: Int
        var lastPracticedAt: Date?
        var nextReviewAt: Date?
        var createdAt: Date
        var groupID: UUID?          // Beziehung über stabile id, nicht Objektgraph
    }
}

extension VocabBackup {

    /// Snapshot aus den lebenden Modellen.
    init(from groups: [VocabGroup], vocabs: [Vocab]) {
        self.groups = groups.map {
            GroupDTO(id: $0.id, name: $0.name, colorHex: $0.colorHex,
                     sortOrder: $0.sortOrder, createdAt: $0.createdAt)
        }
        self.vocabs = vocabs.map {
            VocabDTO(id: $0.id, word: $0.word, meaning: $0.meaning, example: $0.example,
                     statusRaw: $0.statusRaw, successCounter: $0.successCounter,
                     includeInWidget: $0.includeInWidget, timesPracticed: $0.timesPracticed,
                     lastPracticedAt: $0.lastPracticedAt, nextReviewAt: $0.nextReviewAt,
                     createdAt: $0.createdAt, groupID: $0.group?.id)
        }
    }

    // MARK: - Kodierung

    /// ISO8601 mit Millisekunden, damit Zeitstempel (z.B. `nextReviewAt`) den
    /// Round-Trip verlustarm überstehen und die Datei trotzdem lesbar bleibt.
    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static var encoder: JSONEncoder {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(iso8601.string(from: date))
        }
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return enc
    }

    private static var decoder: JSONDecoder {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            guard let date = iso8601.date(from: string) else {
                throw DecodingError.dataCorruptedError(
                    in: container, debugDescription: "Ungültiges ISO8601-Datum: \(string)")
            }
            return date
        }
        return dec
    }

    static func decode(_ data: Data) throws -> VocabBackup {
        try decoder.decode(VocabBackup.self, from: data)
    }

    /// Schreibt die Sicherung als `.json`-Datei ins temporäre Verzeichnis und gibt
    /// die URL zurück (zum Teilen via Share-Sheet → in Dateien/iCloud Drive sichern).
    static func exportFile(groups: [VocabGroup], vocabs: [Vocab]) throws -> URL {
        let backup = VocabBackup(from: groups, vocabs: vocabs)
        let data = try encoder.encode(backup)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let stamp = formatter.string(from: .now)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("DailyHangul-Backup-\(stamp).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Wiederherstellen / Migration

    /// Idempotenter, id-basierter Upsert in den Kontext: vorhandene Objekte werden
    /// aktualisiert, fehlende eingefügt. Mehrfaches Anwenden derselben Sicherung
    /// führt zum gleichen Zustand (keine Duplikate). Überschreibt keine Objekte,
    /// deren id nicht in der Sicherung vorkommt.
    @MainActor
    func apply(into context: ModelContext) {
        var groupByID: [UUID: VocabGroup] = [:]
        for g in (try? context.fetch(FetchDescriptor<VocabGroup>())) ?? [] {
            groupByID[g.id] = g
        }
        var vocabByID: [UUID: Vocab] = [:]
        for v in (try? context.fetch(FetchDescriptor<Vocab>())) ?? [] {
            vocabByID[v.id] = v
        }

        for dto in groups {
            let group = groupByID[dto.id] ?? {
                let new = VocabGroup(name: dto.name)
                new.id = dto.id
                context.insert(new)
                groupByID[dto.id] = new
                return new
            }()
            group.name = dto.name
            group.colorHex = dto.colorHex
            group.sortOrder = dto.sortOrder
            group.createdAt = dto.createdAt
        }

        for dto in vocabs {
            let vocab = vocabByID[dto.id] ?? {
                let new = Vocab(word: dto.word, meaning: dto.meaning)
                new.id = dto.id
                context.insert(new)
                vocabByID[dto.id] = new
                return new
            }()
            vocab.word = dto.word
            vocab.meaning = dto.meaning
            vocab.example = dto.example
            vocab.statusRaw = dto.statusRaw
            vocab.successCounter = dto.successCounter
            vocab.includeInWidget = dto.includeInWidget
            vocab.timesPracticed = dto.timesPracticed
            vocab.lastPracticedAt = dto.lastPracticedAt
            vocab.nextReviewAt = dto.nextReviewAt
            vocab.createdAt = dto.createdAt
            vocab.group = dto.groupID.flatMap { groupByID[$0] }
        }

        context.saveOrLog()
    }
}
