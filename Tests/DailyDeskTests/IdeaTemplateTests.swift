import Foundation
import XCTest
@testable import Nelyr

final class IdeaTemplateTests: XCTestCase {
    func testTagNormalizationIsStableAndDeduplicated() {
        XCTAssertEqual(
            TagNormalizer.normalize(["#Productivity", "local AI", "local_ai", "Café", ""]),
            ["productivity", "local-ai", "caf"]
        )
    }

    func testTemplatePreservesOriginalAndEscapesYAML() {
        let enrichment = IdeaEnrichment(
            title: "A useful idea",
            summary: "A \"quoted\" summary",
            significance: "It could make capture easier.",
            type: .idea,
            areas: [.creativity, .work],
            tags: ["Productivity"],
            nextStep: "Test it"
        )
        let markdown = IdeaTemplateRenderer.render(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            createdAt: Date(timeIntervalSince1970: 0),
            original: "Exact original thought",
            enrichment: enrichment,
            related: [RelatedIdea(linkName: "Earlier idea", title: "Earlier idea", score: 0.9)],
            model: "gemma3:12b"
        )

        XCTAssertTrue(markdown.contains("Exact original thought"))
        XCTAssertTrue(markdown.contains("summary: \"A \\\"quoted\\\" summary\""))
        XCTAssertTrue(markdown.contains("type: idea"))
        XCTAssertTrue(markdown.contains("capture_kind: text"))
        XCTAssertTrue(markdown.contains("  - creativity"))
        XCTAssertTrue(markdown.contains("## Why it matters\n\nIt could make capture easier."))
        XCTAssertTrue(markdown.contains("[[Earlier idea]]"))
        XCTAssertTrue(markdown.contains("#type/idea #area/creativity #area/work #productivity"))
    }

    func testReflectionDoesNotReceiveAForcedAction() {
        let enrichment = IdeaEnrichment(
            title: "A quiet reflection",
            summary: "A faithful summary.",
            significance: "It records a pattern worth remembering.",
            type: .reflection,
            areas: [.selfArea],
            tags: [],
            nextStep: ""
        )
        let markdown = IdeaTemplateRenderer.render(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 0),
            original: "I noticed something about myself.",
            enrichment: enrichment,
            related: [],
            model: "test"
        )

        XCTAssertTrue(markdown.contains("## Possible next step\n\nNo action needed."))
        XCTAssertTrue(enrichment.isValid)
    }

    func testInvalidLifeClassificationIsRejected() {
        XCTAssertFalse(IdeaEnrichment(
            title: "Duplicate area",
            summary: "Summary",
            significance: "Significance",
            type: .goal,
            areas: [.travel, .travel],
            tags: [],
            nextStep: "Plan"
        ).isValid)
        XCTAssertFalse(IdeaEnrichment(
            title: "Still pending",
            summary: "Summary",
            significance: "Significance",
            type: .unclassified,
            areas: [.selfArea],
            tags: [],
            nextStep: ""
        ).isValid)
    }

    func testSafeFilenameRemovesPathCharacters() {
        let filename = IdeaTemplateRenderer.safeFilename(
            for: "Plan: notes/ideas?",
            createdAt: Date(timeIntervalSince1970: 0),
            id: UUID(uuidString: "ABCDEF00-0000-0000-0000-000000000000")!
        )
        XCTAssertFalse(filename.contains("/"))
        XCTAssertFalse(filename.contains(":"))
        XCTAssertTrue(filename.hasSuffix(".md"))
    }

    func testCosineSimilarity() {
        XCTAssertEqual(VectorMath.cosineSimilarity([1, 0], [1, 0]), 1, accuracy: 0.0001)
        XCTAssertEqual(VectorMath.cosineSimilarity([1, 0], [0, 1]), 0, accuracy: 0.0001)
    }
}
