import AppIntents
import Foundation
import WidgetKit

struct ToggleWidgetPriorityIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Nelyr Priority"
    static let description = IntentDescription("Mark a Nelyr priority complete or incomplete from the widget.")
    static let openAppWhenRun = false

    @Parameter(title: "Priority ID")
    var priorityID: String

    init() {}

    init(priorityID: UUID) {
        self.priorityID = priorityID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: priorityID) else { return .result() }
        var snapshot = WidgetSnapshotStore.read()
        guard snapshot.togglePriority(id) else { return .result() }
        WidgetSnapshotStore.write(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: "DailyDeskWidget")
        return .result()
    }
}

struct DeleteWidgetPriorityIntent: AppIntent {
    static let title: LocalizedStringResource = "Delete Nelyr Priority"
    static let description = IntentDescription("Delete a Nelyr priority from the widget.")
    static let openAppWhenRun = false

    @Parameter(title: "Priority ID")
    var priorityID: String

    init() {}

    init(priorityID: UUID) {
        self.priorityID = priorityID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: priorityID) else { return .result() }
        var snapshot = WidgetSnapshotStore.read()
        guard snapshot.deletePriority(id) else { return .result() }
        WidgetSnapshotStore.write(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: "DailyDeskWidget")
        return .result()
    }
}
