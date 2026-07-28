import Foundation

enum ResearchDepth: String, CaseIterable, Codable, Identifiable, Sendable {
    case quick
    case deep

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quick: "Quick Search"
        case .deep: "Deep Research"
        }
    }

    var detail: String {
        switch self {
        case .quick: "A focused answer from a few authoritative sources. Usually faster and lighter on quota."
        case .deep: "Broader source comparison, contradictions, uncertainty, and practical conclusions. Uses more time and Grok quota."
        }
    }

    var maxTurns: Int {
        switch self {
        case .quick: 6
        case .deep: 16
        }
    }

    var reasoningEffort: String {
        switch self {
        case .quick: "medium"
        case .deep: "high"
        }
    }
}

enum ResearchProgress: Equatable, Sendable {
    case starting
    case searching
    case writing(delta: String, characterCount: Int)
    case saving
}

enum ResearchState: Equatable, Sendable {
    case idle
    case researching(ResearchProgress)
    case completed
    case failed(String)

    var isBusy: Bool {
        if case .researching = self { return true }
        return false
    }
}

struct ResearchUsage: Codable, Equatable, Sendable {
    let inputTokens: Int?
    let cachedInputTokens: Int?
    let outputTokens: Int?
    let reasoningTokens: Int?
    let totalTokens: Int?
    let turns: Int?
    let costUSD: Double?
}

struct GrokResearchResponse: Equatable, Sendable {
    let markdown: String
    let sessionID: String?
    let requestID: String?
    let usage: ResearchUsage
}

struct ResearchResult: Identifiable, Equatable, Sendable {
    let id: UUID
    let createdAt: Date
    let query: String
    let depth: ResearchDepth
    let markdown: String
    let fileURL: URL
    let sessionID: String?
    let requestID: String?
    let usage: ResearchUsage
}

enum ResearchError: LocalizedError, Equatable {
    case grokNotInstalled
    case grokFailed(String)
    case emptyResponse
    case cancelled
    case vaultNotConfigured

    var errorDescription: String? {
        switch self {
        case .grokNotInstalled: "Grok CLI was not found. Install or sign in to Grok Build first."
        case .grokFailed(let message): "Grok research failed: \(message)"
        case .emptyResponse: "Grok finished without returning a research answer."
        case .cancelled: "Research was cancelled."
        case .vaultNotConfigured: "Choose an Obsidian vault before starting voice research."
        }
    }
}
