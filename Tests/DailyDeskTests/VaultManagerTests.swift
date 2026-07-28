import Foundation
import XCTest
@testable import Nelyr

@MainActor
final class VaultManagerTests: XCTestCase {
    func testRawCaptureAndEnrichmentAreAtomic() throws {
        let suite = "VaultManagerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DailyDeskVault-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let vault = VaultManager(defaults: defaults)
        vault.setVault(root)

        let captured = try vault.capture("Original thought", template: IdeaTemplateRenderer.defaultTemplate)
        XCTAssertTrue(FileManager.default.fileExists(atPath: captured.fileURL.path))
        let raw = try String(contentsOf: captured.fileURL, encoding: .utf8)
        XCTAssertTrue(raw.contains("status: needs-enrichment"))
        XCTAssertTrue(raw.contains("type: unclassified"))
        XCTAssertTrue(raw.contains("areas:\n  []"))
        XCTAssertTrue(raw.contains("Original thought"))

        let finalURL = try vault.enrich(
            captured,
            enrichment: IdeaEnrichment(
                title: "A linked thought",
                summary: "Concise summary.",
                significance: "It may help organize personal knowledge.",
                type: .learning,
                areas: [.selfArea],
                tags: ["Knowledge"],
                nextStep: "Review it"
            ),
            related: [],
            model: "test-model",
            template: IdeaTemplateRenderer.defaultTemplate
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: finalURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: captured.fileURL.path))
        let enriched = try String(contentsOf: finalURL, encoding: .utf8)
        XCTAssertTrue(enriched.contains("status: inbox"))
        XCTAssertTrue(enriched.contains("Original thought"))
        XCTAssertTrue(enriched.contains("Concise summary."))
        XCTAssertTrue(enriched.contains("type/learning"))
        XCTAssertTrue(enriched.contains("area/self"))
    }

    func testResearchIsSavedAsPortableMarkdown() throws {
        let suite = "VaultManagerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DailyDeskResearchVault-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let vault = VaultManager(defaults: defaults)
        vault.setVault(root)
        let response = GrokResearchResponse(
            markdown: "# 調査結果\n\n引用付きの回答。[Source](https://example.com)",
            sessionID: "session-1",
            requestID: "request-1",
            usage: ResearchUsage(
                inputTokens: 10,
                cachedInputTokens: 20,
                outputTokens: 30,
                reasoningTokens: 5,
                totalTokens: 60,
                turns: 4,
                costUSD: nil
            )
        )

        let url = try vault.saveResearch(
            id: UUID(),
            createdAt: Date(),
            query: "日本語で調べて",
            depth: .deep,
            response: response
        )

        XCTAssertEqual(url.deletingLastPathComponent().lastPathComponent, "Research")
        let markdown = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(markdown.contains("type: research"))
        XCTAssertTrue(markdown.contains("depth: deep"))
        XCTAssertTrue(markdown.contains("日本語で調べて"))
        XCTAssertTrue(markdown.contains("https://example.com"))
        XCTAssertTrue(markdown.contains("Total tokens: 60"))
    }

    func testScreenshotCaptureSavesAttachmentAndKeepsEmbedAfterEnrichment() throws {
        let suite = "VaultManagerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DailyDeskScreenshotVault-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let vault = VaultManager(defaults: defaults)
        vault.setVault(root)

        let imageData = Data([0x89, 0x50, 0x4E, 0x47])
        let captured = try vault.captureScreenshot(
            context: "Remember this interface",
            recognizedText: "Local OCR text\n日本語も保存",
            pngData: imageData,
            template: IdeaTemplateRenderer.defaultTemplate
        )

        XCTAssertEqual(captured.captureKind, .screenshot)
        let raw = try String(contentsOf: captured.fileURL, encoding: .utf8)
        XCTAssertTrue(raw.contains("capture_kind: screenshot"))
        XCTAssertTrue(raw.contains("![[Attachments/Screenshot-"))
        XCTAssertTrue(raw.contains("Local OCR text"))
        let attachments = try FileManager.default.contentsOfDirectory(
            at: root.appendingPathComponent("Attachments"),
            includingPropertiesForKeys: nil
        )
        XCTAssertEqual(attachments.count, 1)
        XCTAssertEqual(try Data(contentsOf: attachments[0]), imageData)

        let finalURL = try vault.enrich(
            captured,
            enrichment: IdeaEnrichment(
                title: "Saved interface reference",
                summary: "A screenshot reference.",
                significance: "It preserves useful visual context.",
                type: .learning,
                areas: [.work],
                tags: ["interface"],
                nextStep: ""
            ),
            related: [],
            model: "test-model",
            template: IdeaTemplateRenderer.defaultTemplate
        )
        let enriched = try String(contentsOf: finalURL, encoding: .utf8)
        XCTAssertTrue(enriched.contains("capture_kind: screenshot"))
        XCTAssertTrue(enriched.contains("![[Attachments/Screenshot-"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: attachments[0].path))
    }
}
