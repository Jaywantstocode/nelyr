import XCTest
@testable import Nelyr

final class WidgetSnapshotTests: XCTestCase {
    func testWidgetCanToggleAndDeletePriorities() {
        let first = UUID()
        let second = UUID()
        var snapshot = WidgetSnapshot(
            updatedAt: .distantPast,
            priorities: [
                .init(id: first, title: "First", isComplete: false),
                .init(id: second, title: "Second", isComplete: true)
            ],
            completedCount: 1,
            timerText: "25:00",
            timerIsRunning: false,
            shortcuts: []
        )

        XCTAssertTrue(snapshot.togglePriority(first))
        XCTAssertEqual(snapshot.completedCount, 2)
        XCTAssertTrue(snapshot.priorities[0].isComplete)

        XCTAssertTrue(snapshot.deletePriority(second))
        XCTAssertEqual(snapshot.priorities.map(\.id), [first])
        XCTAssertEqual(snapshot.completedCount, 1)
    }

    func testOlderSnapshotWithoutShortcutOrPriorityTimestampStillDecodes() throws {
        let id = UUID()
        let json = """
        {
          "updatedAt": 100,
          "priorities": [{"id": "\(id.uuidString)", "title": "Old", "isComplete": false}],
          "completedCount": 0,
          "timerText": "25:00",
          "timerIsRunning": false
        }
        """

        let snapshot = try JSONDecoder().decode(WidgetSnapshot.self, from: Data(json.utf8))

        XCTAssertEqual(snapshot.prioritiesUpdatedAt, snapshot.updatedAt)
        XCTAssertEqual(snapshot.shortcuts.count, 3)
        XCTAssertEqual(snapshot.priorities.first?.id, id)
    }
}
