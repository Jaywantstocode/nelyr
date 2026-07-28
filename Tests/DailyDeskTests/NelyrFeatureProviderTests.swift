import Foundation
import NelyrCommunity
import NelyrCore
import XCTest
@testable import Nelyr

@MainActor
final class NelyrFeatureProviderTests: XCTestCase {
    func testCommunityManifestKeepsCoreCaptureOpenWithoutProCapabilities() {
        let manifest = NelyrCommunityFeatures().manifest

        XCTAssertEqual(manifest.edition, .community)
        XCTAssertTrue(manifest.supports(.rawCapture))
        XCTAssertTrue(manifest.supports(.localTranscription))
        XCTAssertTrue(manifest.supports(.obsidianInbox))
        XCTAssertFalse(manifest.supports(.advancedKnowledgeGraph))
        XCTAssertFalse(manifest.supports(.multipleVaults))
        XCTAssertFalse(manifest.supports(.managedUpdates))
    }

    func testCaptureSurvivesWithoutAnOptionalKnowledgeEngine() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("NelyrFeatureTests-\(UUID().uuidString)", isDirectory: true)
        let suite = "NelyrFeatureTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: root)
        }

        let vault = VaultManager(defaults: defaults)
        vault.setVault(root)
        let settings = DailyDeskSettings(defaults: defaults)
        let provider = CommunityFeatureProvider(knowledgeEngine: nil)
        let pipeline = IdeaPipeline(
            featureProvider: provider,
            vault: vault,
            settings: settings
        )

        XCTAssertTrue(pipeline.capture("Keep this thought even when every optional engine is absent."))
        XCTAssertEqual(pipeline.pendingCount, 0)
        XCTAssertEqual(pipeline.phase, .completed("Saved locally"))

        let notes = try FileManager.default.contentsOfDirectory(
            at: try XCTUnwrap(vault.ideasDirectory),
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "md" }
        let note = try String(contentsOf: try XCTUnwrap(notes.first), encoding: .utf8)
        XCTAssertTrue(note.contains("Keep this thought even when every optional engine is absent."))
        XCTAssertTrue(note.contains("status: needs-enrichment"))
    }
}
