import Foundation
import XCTest
@testable import Nelyr

final class GrokResearchClientTests: XCTestCase {
    func testStreamingParserHandlesSplitNDJSONAndUsage() {
        var parser = GrokStreamParser()
        let first = Data("{\"type\":\"thought\",\"data\":\"searching\"}\n{\"type\":\"text\",\"data\":\"日本".utf8)
        let second = Data("語の回答\"}\n{\"type\":\"end\",\"sessionId\":\"session-1\",\"requestId\":\"request-1\",\"num_turns\":4,\"usage\":{\"input_tokens\":10,\"cache_read_input_tokens\":20,\"output_tokens\":30,\"reasoning_tokens\":5,\"total_tokens\":60}}\n".utf8)

        let firstEvents = parser.ingest(first)
        let secondEvents = parser.ingest(second)

        XCTAssertEqual(firstEvents, [.thought])
        XCTAssertEqual(secondEvents.count, 2)
        XCTAssertEqual(secondEvents.first, .text("日本語の回答"))
        guard case .end(let metadata) = secondEvents.last else {
            return XCTFail("Expected an end event")
        }
        XCTAssertEqual(metadata.sessionID, "session-1")
        XCTAssertEqual(metadata.requestID, "request-1")
        XCTAssertEqual(metadata.usage.totalTokens, 60)
        XCTAssertEqual(metadata.usage.turns, 4)
    }

    func testCLIArgumentsRestrictToolsAndBoundTurns() {
        let arguments = GrokResearchClient.arguments(query: "調べて", depth: .deep)

        XCTAssertTrue(arguments.contains("web_search,web_fetch"))
        XCTAssertTrue(arguments.contains("--no-memory"))
        XCTAssertTrue(arguments.contains("--no-subagents"))
        XCTAssertTrue(arguments.contains("MCPTool(*)"))
        XCTAssertTrue(arguments.contains("Bash"))
        XCTAssertFalse(arguments.contains("--check"))
        XCTAssertTrue(arguments.contains("high"))
        XCTAssertFalse(arguments.contains("xhigh"))
        XCTAssertTrue(arguments.contains(String(ResearchDepth.deep.maxTurns)))
        XCTAssertFalse(arguments.contains("run_terminal_cmd"))
        XCTAssertFalse(arguments.contains("search_replace"))
    }

    func testSafeEnvironmentDisablesCompatibilityAndBackgroundFeatures() {
        let environment = GrokResearchClient.safeEnvironment(base: ["PATH": "/usr/bin"])

        XCTAssertEqual(environment["PATH"], "/usr/bin")
        XCTAssertEqual(environment["GROK_CLAUDE_MCPS_ENABLED"], "false")
        XCTAssertEqual(environment["GROK_CURSOR_SKILLS_ENABLED"], "false")
        XCTAssertEqual(environment["GROK_MEMORY"], "0")
        XCTAssertEqual(environment["GROK_SUBAGENTS"], "0")
        XCTAssertEqual(environment["GROK_MCP_AUTO_RESTART"], "0")
    }

    func testFinalReportDropsPreSearchNarration() {
        let streamed = "公式ページを確認します。\n\n# 調査結果\n\n## Bottom line\n本文"

        XCTAssertEqual(
            GrokResearchClient.finalReport(from: streamed),
            "# 調査結果\n\n## Bottom line\n本文"
        )
    }
}
