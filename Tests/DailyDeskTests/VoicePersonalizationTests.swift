import Foundation
import XCTest
@testable import Nelyr

@MainActor
final class VoicePersonalizationTests: XCTestCase {
    func testDictionaryDeduplicatesAndImportsCSV() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let csv = directory.appendingPathComponent("terms.csv")
        try "WhisperKit\nDaily Desk,product\n".write(to: csv, atomically: true, encoding: .utf8)
        let store = PersonalDictionaryStore(storageURL: directory.appendingPathComponent("dictionary.json"))

        XCTAssertTrue(store.add("Ollama"))
        XCTAssertFalse(store.add("ollama"))
        XCTAssertEqual(store.importCSV(from: csv), 2)
        XCTAssertEqual(Set(store.terms), Set(["Ollama", "WhisperKit", "Daily Desk"]))
    }

    func testHistoryRetentionAndDeletion() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("history-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = DictationHistoryStore(storageURL: url)
        let context = DictationAppContext(appName: "Notes", bundleIdentifier: "com.apple.Notes")
        store.add(item(createdAt: Date().addingTimeInterval(-100_000), context: context), retention: .forever)
        store.add(item(createdAt: Date(), context: context), retention: .day)
        XCTAssertEqual(store.items.count, 1)
        store.deleteAll()
        XCTAssertTrue(store.items.isEmpty)
    }

    private func item(createdAt: Date, context: DictationAppContext) -> DictationHistoryItem {
        DictationHistoryItem(
            id: UUID(),
            createdAt: createdAt,
            rawText: "raw",
            outputText: "output",
            detectedLanguage: "en",
            duration: 1,
            mode: .dictation,
            appContext: context
        )
    }
}
