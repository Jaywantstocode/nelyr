import Foundation

struct DictationHistoryItem: Codable, Identifiable, Equatable, Sendable {
    enum Mode: String, Codable, Sendable {
        case dictation, translation, voiceEdit

        var title: String {
            switch self {
            case .dictation: "Dictation"
            case .translation: "Translation"
            case .voiceEdit: "Voice Edit"
            }
        }
    }

    let id: UUID
    let createdAt: Date
    let rawText: String
    let outputText: String
    let detectedLanguage: String?
    let duration: TimeInterval
    let mode: Mode
    let appContext: DictationAppContext
}

@MainActor
final class DictationHistoryStore: ObservableObject {
    static let shared = DictationHistoryStore()

    @Published private(set) var items: [DictationHistoryItem] = []
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let storageOverride: URL?

    init(storageURL: URL? = nil) {
        storageOverride = storageURL
        load()
    }

    func add(_ item: DictationHistoryItem, retention: VoiceHistoryRetention) {
        guard retention != .never else { return }
        items.insert(item, at: 0)
        prune(retention: retention)
        persist()
    }

    func delete(_ id: UUID) {
        items.removeAll { $0.id == id }
        persist()
    }

    func deleteAll() {
        items.removeAll()
        persist()
    }

    func apply(retention: VoiceHistoryRetention) {
        if retention == .never { items.removeAll() }
        else { prune(retention: retention) }
        persist()
    }

    private func prune(retention: VoiceHistoryRetention) {
        guard let interval = retention.interval else { return }
        let cutoff = Date().addingTimeInterval(-interval)
        items.removeAll { $0.createdAt < cutoff }
    }

    private var storageURL: URL {
        if let storageOverride { return storageOverride }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = support.appendingPathComponent("DailyDesk", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("dictation-history.json")
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? decoder.decode([DictationHistoryItem].self, from: data) else { return }
        items = decoded
    }

    private func persist() {
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }
}

struct PersonalDictionaryEntry: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var term: String
    let createdAt: Date
}

@MainActor
final class PersonalDictionaryStore: ObservableObject {
    static let shared = PersonalDictionaryStore()

    @Published private(set) var entries: [PersonalDictionaryEntry] = []
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let storageOverride: URL?

    init(storageURL: URL? = nil) {
        storageOverride = storageURL
        load()
    }

    var terms: [String] { entries.map(\.term) }

    @discardableResult
    func add(_ raw: String) -> Bool {
        let term = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty,
              !entries.contains(where: { $0.term.localizedCaseInsensitiveCompare(term) == .orderedSame }) else {
            return false
        }
        entries.append(PersonalDictionaryEntry(id: UUID(), term: term, createdAt: Date()))
        entries.sort { $0.term.localizedCaseInsensitiveCompare($1.term) == .orderedAscending }
        persist()
        return true
    }

    func update(_ id: UUID, term raw: String) {
        let term = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty, let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].term = term
        entries.sort { $0.term.localizedCaseInsensitiveCompare($1.term) == .orderedAscending }
        persist()
    }

    func delete(_ id: UUID) {
        entries.removeAll { $0.id == id }
        persist()
    }

    func importCSV(from url: URL) -> Int {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return 0 }
        var added = 0
        for line in content.components(separatedBy: .newlines) {
            let firstColumn = line.split(separator: ",", maxSplits: 1).first.map(String.init) ?? line
            if add(firstColumn.trimmingCharacters(in: CharacterSet(charactersIn: " \t\""))) { added += 1 }
        }
        return added
    }

    private var storageURL: URL {
        if let storageOverride { return storageOverride }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = support.appendingPathComponent("DailyDesk", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("personal-dictionary.json")
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? decoder.decode([PersonalDictionaryEntry].self, from: data) else { return }
        entries = decoded
    }

    private func persist() {
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }
}
