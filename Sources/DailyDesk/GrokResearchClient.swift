import Foundation

protocol ResearchRunning: Sendable {
    func run(
        query: String,
        depth: ResearchDepth,
        onProgress: @escaping @Sendable (ResearchProgress) -> Void
    ) async throws -> GrokResearchResponse
    func cancel() async
}

actor GrokResearchClient: ResearchRunning {
    static let shared = GrokResearchClient()

    private var activeProcess: Process?

    nonisolated static var defaultExecutableURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".grok/bin/grok", isDirectory: false)
    }

    nonisolated static func arguments(query: String, depth: ResearchDepth) -> [String] {
        let values = [
            "--single", researchPrompt(query: query, depth: depth),
            "--output-format", "streaming-json",
            "--model", "grok-4.5",
            "--tools", "web_search,web_fetch",
            "--no-memory",
            "--no-subagents",
            "--deny", "MCPTool(*)",
            "--deny", "Bash",
            "--deny", "Read",
            "--deny", "Edit",
            "--deny", "Grep",
            "--max-turns", String(depth.maxTurns),
            "--reasoning-effort", depth.reasoningEffort,
            "--cwd", "/private/tmp",
            "--rules", "Use only web_search and web_fetch. Never use local files, shell commands, MCP servers, memory, or subagents."
        ]
        return values
    }

    nonisolated static func safeEnvironment(base: [String: String]) -> [String: String] {
        var environment = base
        let compatibilitySwitches = [
            "GROK_CLAUDE_MCPS_ENABLED",
            "GROK_CLAUDE_SKILLS_ENABLED",
            "GROK_CLAUDE_RULES_ENABLED",
            "GROK_CLAUDE_AGENTS_ENABLED",
            "GROK_CLAUDE_HOOKS_ENABLED",
            "GROK_CLAUDE_SESSIONS_ENABLED",
            "GROK_CURSOR_MCPS_ENABLED",
            "GROK_CURSOR_SKILLS_ENABLED",
            "GROK_CURSOR_RULES_ENABLED",
            "GROK_CURSOR_AGENTS_ENABLED",
            "GROK_CURSOR_HOOKS_ENABLED",
            "GROK_CURSOR_SESSIONS_ENABLED"
        ]
        for key in compatibilitySwitches { environment[key] = "false" }
        environment["GROK_MEMORY"] = "0"
        environment["GROK_SUBAGENTS"] = "0"
        environment["GROK_TELEMETRY_ENABLED"] = "0"
        environment["DISABLE_TELEMETRY"] = "1"
        environment["GROK_DISABLE_AUTOUPDATER"] = "1"
        environment["GROK_MCP_AUTO_RESTART"] = "0"
        environment["GROK_MCP_STARTUP_TIMEOUT_SECS"] = "1"
        environment["MCP_TIMEOUT"] = "1000"
        environment["CMUX_GROK_HOOKS_DISABLED"] = "1"
        return environment
    }

    nonisolated static func finalReport(from streamedText: String) -> String {
        let trimmed = streamedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let heading = trimmed.range(of: #"(?m)^#\s+\S"#, options: .regularExpression) else {
            return trimmed
        }
        return String(trimmed[heading.lowerBound...])
    }

    func run(
        query: String,
        depth: ResearchDepth,
        onProgress: @escaping @Sendable (ResearchProgress) -> Void
    ) async throws -> GrokResearchResponse {
        try await withTaskCancellationHandler {
            try await execute(query: query, depth: depth, onProgress: onProgress)
        } onCancel: {
            Task { await self.cancel() }
        }
    }

    func cancel() {
        guard let activeProcess, activeProcess.isRunning else { return }
        activeProcess.terminate()
    }

    private func execute(
        query: String,
        depth: ResearchDepth,
        onProgress: @escaping @Sendable (ResearchProgress) -> Void
    ) async throws -> GrokResearchResponse {
        let executableURL = Self.defaultExecutableURL
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw ResearchError.grokNotInstalled
        }

        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = executableURL
        process.arguments = Self.arguments(query: query, depth: depth)
        process.environment = Self.safeEnvironment(base: ProcessInfo.processInfo.environment)
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        activeProcess = process
        defer {
            outputPipe.fileHandleForReading.readabilityHandler = nil
            activeProcess = nil
        }

        let outputStream = Self.stream(for: outputPipe.fileHandleForReading)
        let errorStream = Self.stream(for: errorPipe.fileHandleForReading)
        let errorTask = Task { () -> Data in
            var collected = Data()
            for await chunk in errorStream { collected.append(chunk) }
            return collected
        }

        onProgress(.starting)
        do {
            try process.run()
        } catch {
            errorTask.cancel()
            throw ResearchError.grokFailed(error.localizedDescription)
        }

        var parser = GrokStreamParser()
        var markdown = ""
        var sessionID: String?
        var requestID: String?
        var usage = ResearchUsage(
            inputTokens: nil,
            cachedInputTokens: nil,
            outputTokens: nil,
            reasoningTokens: nil,
            totalTokens: nil,
            turns: nil,
            costUSD: nil
        )
        var reportedSearch = false

        for await chunk in outputStream {
            try Task.checkCancellation()
            for event in parser.ingest(chunk) {
                switch event {
                case .text(let text):
                    markdown += text
                    onProgress(.writing(delta: text, characterCount: markdown.count))
                case .thought:
                    if !reportedSearch {
                        reportedSearch = true
                        onProgress(.searching)
                    }
                case .end(let metadata):
                    sessionID = metadata.sessionID
                    requestID = metadata.requestID
                    usage = metadata.usage
                case .error(let message):
                    throw ResearchError.grokFailed(message)
                }
            }
        }
        for event in parser.finish() {
            if case .text(let text) = event {
                markdown += text
                onProgress(.writing(delta: text, characterCount: markdown.count))
            }
        }

        process.waitUntilExit()
        let errorData = await errorTask.value
        try Task.checkCancellation()
        guard process.terminationStatus == 0 else {
            let message = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw ResearchError.grokFailed(message?.isEmpty == false ? message! : "Process exited with status \(process.terminationStatus).")
        }

        markdown = Self.finalReport(from: markdown)
        guard !markdown.isEmpty else { throw ResearchError.emptyResponse }
        return GrokResearchResponse(
            markdown: markdown,
            sessionID: sessionID,
            requestID: requestID,
            usage: usage
        )
    }

    private nonisolated static func stream(for handle: FileHandle) -> AsyncStream<Data> {
        AsyncStream { continuation in
            handle.readabilityHandler = { readable in
                let data = readable.availableData
                if data.isEmpty {
                    readable.readabilityHandler = nil
                    continuation.finish()
                } else {
                    continuation.yield(data)
                }
            }
            continuation.onTermination = { _ in
                handle.readabilityHandler = nil
            }
        }
    }

    private nonisolated static func researchPrompt(query: String, depth: ResearchDepth) -> String {
        let depthInstructions: String
        switch depth {
        case .quick:
            depthInstructions = "Answer efficiently using several authoritative and current sources. Prefer primary sources."
        case .deep:
            depthInstructions = "Research broadly and deeply. Compare independent sources, prioritize primary evidence, identify disagreement, test major claims, and clearly state uncertainty and limitations before forming a practical conclusion."
        }
        return """
        You are researching a voice question for a private personal knowledge base.
        \(depthInstructions)
        Use web search and open relevant pages. Do not rely only on snippets.
        Do not narrate what you are about to search or how you are using tools. Your first visible output must be the final report's Markdown H1 heading.
        Reply in the same language and writing system as the question; never translate Japanese into English.
        Return polished Markdown with this structure:
        # A specific research title
        ## Bottom line
        ## Findings
        ## Nuance and uncertainty
        ## Practical next steps
        ## Sources
        In Sources, include direct Markdown links and one short note explaining what each source supports. Use inline links near important claims too. Never invent a URL or citation.

        QUESTION:
        \(query.trimmingCharacters(in: .whitespacesAndNewlines))
        """
    }
}

enum GrokStreamEvent: Equatable, Sendable {
    case text(String)
    case thought
    case end(GrokEndMetadata)
    case error(String)
}

struct GrokEndMetadata: Equatable, Sendable {
    let sessionID: String?
    let requestID: String?
    let usage: ResearchUsage
}

struct GrokStreamParser: Sendable {
    private var buffer = Data()

    mutating func ingest(_ data: Data) -> [GrokStreamEvent] {
        buffer.append(data)
        var events: [GrokStreamEvent] = []
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = Data(buffer[..<newline])
            buffer.removeSubrange(...newline)
            if let event = Self.decode(line) { events.append(event) }
        }
        return events
    }

    mutating func finish() -> [GrokStreamEvent] {
        defer { buffer.removeAll() }
        guard !buffer.isEmpty, let event = Self.decode(buffer) else { return [] }
        return [event]
    }

    private static func decode(_ data: Data) -> GrokStreamEvent? {
        guard !data.isEmpty,
              let raw = try? JSONDecoder().decode(RawGrokStreamEvent.self, from: data) else { return nil }
        switch raw.type {
        case "text": return .text(raw.data ?? "")
        case "thought": return .thought
        case "error": return .error(raw.message ?? "Unknown Grok error")
        case "end":
            return .end(GrokEndMetadata(
                sessionID: raw.sessionId,
                requestID: raw.requestId,
                usage: ResearchUsage(
                    inputTokens: raw.usage?.inputTokens,
                    cachedInputTokens: raw.usage?.cachedInputTokens,
                    outputTokens: raw.usage?.outputTokens,
                    reasoningTokens: raw.usage?.reasoningTokens,
                    totalTokens: raw.usage?.totalTokens,
                    turns: raw.numTurns,
                    costUSD: raw.totalCostUSD
                )
            ))
        default: return nil
        }
    }
}

private struct RawGrokStreamEvent: Decodable {
    struct Usage: Decodable {
        let inputTokens: Int?
        let cachedInputTokens: Int?
        let outputTokens: Int?
        let reasoningTokens: Int?
        let totalTokens: Int?

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case cachedInputTokens = "cache_read_input_tokens"
            case outputTokens = "output_tokens"
            case reasoningTokens = "reasoning_tokens"
            case totalTokens = "total_tokens"
        }
    }

    let type: String
    let data: String?
    let message: String?
    let sessionId: String?
    let requestId: String?
    let usage: Usage?
    let numTurns: Int?
    let totalCostUSD: Double?

    enum CodingKeys: String, CodingKey {
        case type, data, message, usage
        case sessionId, requestId
        case numTurns = "num_turns"
        case totalCostUSD = "total_cost_usd"
    }
}
