import XCTest
@testable import Nelyr

@MainActor
final class DailyDeskModelTests: XCTestCase {
    private func makeStorageURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("DailyDeskTests-\(UUID().uuidString).json")
    }

    func testPrioritiesCanBeAddedCompletedAndPersisted() {
        let storageURL = makeStorageURL()
        defer { try? FileManager.default.removeItem(at: storageURL) }
        let model = DailyDeskModel(storageURL: storageURL)

        model.addPriority("  Ship the important thing  ")
        XCTAssertEqual(model.priorities.map(\.title), ["Ship the important thing"])
        XCTAssertEqual(model.openPriorityCount, 1)

        let id = model.priorities[0].id
        model.togglePriority(id)
        XCTAssertEqual(model.completedCount, 1)
        XCTAssertEqual(model.progress, 1)

        let restored = DailyDeskModel(storageURL: storageURL)
        XCTAssertEqual(restored.priorities.count, 1)
        XCTAssertTrue(restored.priorities[0].isComplete)
    }

    func testCaptureScratchpadAndDeletionPersist() {
        let storageURL = makeStorageURL()
        defer { try? FileManager.default.removeItem(at: storageURL) }
        let model = DailyDeskModel(storageURL: storageURL)
        model.addCapture("Remember this")
        model.updateScratchpad("Working notes")

        XCTAssertEqual(model.captures.first?.text, "Remember this")
        XCTAssertEqual(model.scratchpad, "Working notes")

        let captureID = model.captures[0].id
        model.deleteCapture(captureID)

        let restored = DailyDeskModel(storageURL: storageURL)
        XCTAssertTrue(restored.captures.isEmpty)
        XCTAssertEqual(restored.scratchpad, "Working notes")
    }

    func testBlankEntriesAreIgnored() {
        let storageURL = makeStorageURL()
        defer { try? FileManager.default.removeItem(at: storageURL) }
        let model = DailyDeskModel(storageURL: storageURL)
        model.addPriority("   ")
        model.addCapture("\n")

        XCTAssertTrue(model.priorities.isEmpty)
        XCTAssertTrue(model.captures.isEmpty)
    }
}
