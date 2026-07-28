import Foundation

struct WidgetSnapshot: Codable {
    struct Item: Codable, Identifiable {
        var id: UUID
        var title: String
        var isComplete: Bool
    }

    struct Shortcut: Codable, Identifiable {
        let id: String
        let name: String
        let keys: String
    }

    var updatedAt: Date
    var prioritiesUpdatedAt: Date
    var priorities: [Item]
    var completedCount: Int
    var timerText: String
    var timerIsRunning: Bool
    var shortcuts: [Shortcut]

    init(
        updatedAt: Date,
        prioritiesUpdatedAt: Date? = nil,
        priorities: [Item],
        completedCount: Int,
        timerText: String,
        timerIsRunning: Bool,
        shortcuts: [Shortcut]
    ) {
        self.updatedAt = updatedAt
        self.prioritiesUpdatedAt = prioritiesUpdatedAt ?? updatedAt
        self.priorities = priorities
        self.completedCount = completedCount
        self.timerText = timerText
        self.timerIsRunning = timerIsRunning
        self.shortcuts = shortcuts
    }

    mutating func togglePriority(_ id: UUID) -> Bool {
        guard let index = priorities.firstIndex(where: { $0.id == id }) else { return false }
        priorities[index].isComplete.toggle()
        markPrioritiesChanged()
        return true
    }

    mutating func deletePriority(_ id: UUID) -> Bool {
        let originalCount = priorities.count
        priorities.removeAll { $0.id == id }
        guard priorities.count != originalCount else { return false }
        markPrioritiesChanged()
        return true
    }

    private mutating func markPrioritiesChanged() {
        let now = Date()
        prioritiesUpdatedAt = now
        updatedAt = now
        completedCount = priorities.filter(\.isComplete).count
    }

    private enum CodingKeys: String, CodingKey {
        case updatedAt, prioritiesUpdatedAt, priorities, completedCount
        case timerText, timerIsRunning, shortcuts
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        updatedAt = try values.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .distantPast
        prioritiesUpdatedAt = try values.decodeIfPresent(Date.self, forKey: .prioritiesUpdatedAt) ?? updatedAt
        priorities = try values.decodeIfPresent([Item].self, forKey: .priorities) ?? []
        completedCount = try values.decodeIfPresent(Int.self, forKey: .completedCount)
            ?? priorities.filter(\.isComplete).count
        timerText = try values.decodeIfPresent(String.self, forKey: .timerText) ?? "25:00"
        timerIsRunning = try values.decodeIfPresent(Bool.self, forKey: .timerIsRunning) ?? false
        shortcuts = try values.decodeIfPresent([Shortcut].self, forKey: .shortcuts) ?? Self.defaultShortcuts
    }

    private static let defaultShortcuts = [
        Shortcut(id: "capture", name: "Capture", keys: "⌃⌥Space"),
        Shortcut(id: "dictate", name: "Dictate", keys: "⌃⇧Space"),
        Shortcut(id: "research", name: "Research", keys: "⌃⇧R")
    ]

    static let empty = WidgetSnapshot(
        updatedAt: Date(),
        priorities: [],
        completedCount: 0,
        timerText: "25:00",
        timerIsRunning: false,
        shortcuts: defaultShortcuts
    )
}

enum WidgetSnapshotStore {
    static let appGroupID = "FA2MKZLU45.ooo.cavin.dailydesk.shared"
    private static let filename = "widget-snapshot.json"

    static func read() -> WidgetSnapshot {
        readIfAvailable() ?? .empty
    }

    static func readIfAvailable() -> WidgetSnapshot? {
        guard let url = snapshotURL,
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    static func write(_ snapshot: WidgetSnapshot) {
        guard let url = snapshotURL else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private static var snapshotURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(filename)
    }
}
