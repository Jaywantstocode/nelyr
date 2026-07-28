import WidgetKit

@MainActor
enum WidgetSnapshotWriter {
    static func update() {
        let model = DailyDeskModel.shared
        let timer = FocusTimer.shared
        let settings = DailyDeskSettings.shared
        let stored = WidgetSnapshotStore.readIfAvailable()
        let widgetHasNewerPriorities = stored?.prioritiesUpdatedAt ?? .distantPast > model.prioritiesUpdatedAt
        let priorities = widgetHasNewerPriorities
            ? stored?.priorities ?? []
            : model.priorities.map {
                WidgetSnapshot.Item(id: $0.id, title: $0.title, isComplete: $0.isComplete)
            }
        let priorityTimestamp = widgetHasNewerPriorities
            ? stored?.prioritiesUpdatedAt ?? model.prioritiesUpdatedAt
            : model.prioritiesUpdatedAt
        let snapshot = WidgetSnapshot(
            updatedAt: Date(),
            prioritiesUpdatedAt: priorityTimestamp,
            priorities: priorities,
            completedCount: priorities.filter(\.isComplete).count,
            timerText: timer.formattedTime,
            timerIsRunning: timer.isRunning,
            shortcuts: [
                WidgetSnapshot.Shortcut(id: "capture", name: "Capture", keys: "⌃⌥Space"),
                WidgetSnapshot.Shortcut(id: "dictate", name: "Dictate", keys: settings.voiceDictationShortcut.symbols),
                WidgetSnapshot.Shortcut(id: "edit", name: "Voice Edit", keys: settings.voiceEditShortcut.symbols),
                WidgetSnapshot.Shortcut(id: "translate", name: "Translate", keys: settings.translationDictationShortcut.symbols),
                WidgetSnapshot.Shortcut(id: "research", name: "Research", keys: settings.researchDictationShortcut.symbols)
            ]
        )
        WidgetSnapshotStore.write(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: "DailyDeskWidget")
    }
}
