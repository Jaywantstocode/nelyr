import Foundation
import SwiftUI

struct PriorityItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var isComplete = false
}

struct CaptureItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    var createdAt = Date()
}

struct DailyArchive: Identifiable, Codable, Equatable {
    var id = UUID()
    var date: Date
    var completed: Int
    var total: Int
}

private struct StoredState: Codable {
    var activeDate: Date
    var priorities: [PriorityItem]
    var captures: [CaptureItem]
    var scratchpad: String
    var archives: [DailyArchive]
    var prioritiesUpdatedAt: Date?
}

@MainActor
final class DailyDeskModel: ObservableObject {
    static let shared = DailyDeskModel()

    @Published var activeDate = Date()
    @Published var priorities: [PriorityItem] = []
    @Published var captures: [CaptureItem] = []
    @Published var scratchpad = ""
    @Published var archives: [DailyArchive] = []

    private let calendar = Calendar.current
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let storageOverride: URL?
    private var isLoading = true
    private(set) var prioritiesUpdatedAt = Date.distantPast

    init(storageURL: URL? = nil) {
        storageOverride = storageURL
        load()
        rolloverIfNeeded()
        isLoading = false
    }

    var completedCount: Int { priorities.filter(\.isComplete).count }
    var openPriorityCount: Int { priorities.filter { !$0.isComplete }.count }
    var progress: Double {
        guard !priorities.isEmpty else { return 0 }
        return Double(completedCount) / Double(priorities.count)
    }

    var streak: Int {
        let completedDays = archives
            .filter { $0.total > 0 && $0.completed == $0.total }
            .map { calendar.startOfDay(for: $0.date) }
        var unique = Set(completedDays)
        if !priorities.isEmpty && completedCount == priorities.count {
            unique.insert(calendar.startOfDay(for: Date()))
        }

        var cursor = calendar.startOfDay(for: Date())
        if !unique.contains(cursor) {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        var count = 0
        while unique.contains(cursor) {
            count += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return count
    }

    func addPriority(_ raw: String) {
        let title = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        priorities.append(PriorityItem(title: title))
        markPrioritiesChanged()
        persist()
    }

    func togglePriority(_ id: UUID) {
        guard let index = priorities.firstIndex(where: { $0.id == id }) else { return }
        priorities[index].isComplete.toggle()
        markPrioritiesChanged()
        persist()
    }

    func deletePriority(_ id: UUID) {
        let oldCount = priorities.count
        priorities.removeAll { $0.id == id }
        guard priorities.count != oldCount else { return }
        markPrioritiesChanged()
        persist()
    }

    func addCapture(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        captures.insert(CaptureItem(text: text), at: 0)
        persist()
    }

    @discardableResult
    func captureIdea(_ raw: String) -> Bool {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        addCapture(text)
        return IdeaPipeline.shared.capture(text)
    }

    @discardableResult
    func captureScreenshot(context: String, recognizedText: String, pngData: Data) -> Bool {
        let context = context.trimmingCharacters(in: .whitespacesAndNewlines)
        let recognizedText = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let preview = !context.isEmpty ? context : (!recognizedText.isEmpty ? recognizedText : "Screenshot")
        addCapture(String(preview.prefix(500)))
        return IdeaPipeline.shared.captureScreenshot(
            context: context,
            recognizedText: recognizedText,
            pngData: pngData
        )
    }

    func deleteCapture(_ id: UUID) {
        captures.removeAll { $0.id == id }
        persist()
    }

    func updateScratchpad(_ value: String) {
        scratchpad = value
        persist()
    }

    func clearCompleted() {
        let oldCount = priorities.count
        priorities.removeAll( where: \.isComplete)
        guard priorities.count != oldCount else { return }
        markPrioritiesChanged()
        persist()
    }

    func syncPrioritiesFromWidget() {
        guard !isLoading,
              let snapshot = WidgetSnapshotStore.readIfAvailable(),
              snapshot.prioritiesUpdatedAt > prioritiesUpdatedAt else { return }
        priorities = snapshot.priorities.map {
            PriorityItem(id: $0.id, title: $0.title, isComplete: $0.isComplete)
        }
        prioritiesUpdatedAt = snapshot.prioritiesUpdatedAt
        persist(updateWidget: false)
        WidgetSnapshotWriter.update()
    }

    private var stateURL: URL {
        if let storageOverride { return storageOverride }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = support.appendingPathComponent("DailyDesk", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("daily-desk.json")
    }

    private func rolloverIfNeeded() {
        guard !calendar.isDate(activeDate, inSameDayAs: Date()) else { return }

        if !priorities.isEmpty {
            archives.insert(
                DailyArchive(date: activeDate, completed: completedCount, total: priorities.count),
                at: 0
            )
            archives = Array(archives.prefix(60))
        }

        priorities = priorities
            .filter { !$0.isComplete }
            .map { PriorityItem(title: $0.title) }
        markPrioritiesChanged()
        captures = Array(captures.prefix(25))
        scratchpad = ""
        activeDate = Date()
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: stateURL),
              let state = try? decoder.decode(StoredState.self, from: data) else { return }
        activeDate = state.activeDate
        priorities = state.priorities
        captures = state.captures
        scratchpad = state.scratchpad
        archives = state.archives
        prioritiesUpdatedAt = state.prioritiesUpdatedAt
            ?? ((try? FileManager.default.attributesOfItem(atPath: stateURL.path)[.modificationDate]) as? Date)
            ?? .distantPast
    }

    private func persist(updateWidget: Bool = true) {
        guard !isLoading else { return }
        let state = StoredState(
            activeDate: activeDate,
            priorities: priorities,
            captures: captures,
            scratchpad: scratchpad,
            archives: archives,
            prioritiesUpdatedAt: prioritiesUpdatedAt
        )
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: stateURL, options: .atomic)
        if updateWidget { WidgetSnapshotWriter.update() }
    }

    private func markPrioritiesChanged() {
        prioritiesUpdatedAt = Date()
    }
}

@MainActor
final class FocusTimer: ObservableObject {
    static let shared = FocusTimer()

    @Published private(set) var remainingSeconds = 25 * 60
    @Published private(set) var isRunning = false
    @Published private(set) var completedSessions = 0

    private var timer: Timer?

    var formattedTime: String {
        String(format: "%02d:%02d", remainingSeconds / 60, remainingSeconds % 60)
    }

    var progress: Double {
        1 - Double(remainingSeconds) / Double(25 * 60)
    }

    func toggle() {
        isRunning ? pause() : start()
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        WidgetSnapshotWriter.update()
    }

    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        WidgetSnapshotWriter.update()
    }

    func reset() {
        pause()
        remainingSeconds = 25 * 60
        WidgetSnapshotWriter.update()
    }

    private func tick() {
        guard remainingSeconds > 0 else { return }
        remainingSeconds -= 1
        if remainingSeconds % 30 == 0 { WidgetSnapshotWriter.update() }
        if remainingSeconds == 0 {
            completedSessions += 1
            pause()
            NSSound(named: "Glass")?.play()
            NSApplication.shared.requestUserAttention(.informationalRequest)
            NotificationService.shared.sendFocusFinished()
        }
    }
}
