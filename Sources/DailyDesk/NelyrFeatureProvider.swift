import Foundation
import NelyrCommunity
import NelyrCore

struct KnowledgeEngineConfiguration: Equatable, Sendable {
    let generationModel: String
    let embeddingModel: String
    let customInstructions: String
    let noteTemplate: String
}

struct KnowledgeEngineOutcome: Equatable, Sendable {
    let title: String
    let destination: URL
    let installedModels: Set<String>
}

/// Host-facing knowledge contract. A future NelyrProKit can provide a richer
/// implementation without changing capture, vault, or UI code.
@MainActor
protocol KnowledgeEngine: AnyObject {
    func installedModels() async throws -> Set<String>
    func install(model: String) async throws
    func enrich(
        _ note: CapturedNote,
        configuration: KnowledgeEngineConfiguration,
        vault: VaultManager
    ) async throws -> KnowledgeEngineOutcome
}

@MainActor
final class LocalKnowledgeEngine: KnowledgeEngine {
    private let client: OllamaClient
    private let index: EmbeddingIndex

    init(
        client: OllamaClient = OllamaClient(),
        index: EmbeddingIndex = EmbeddingIndex()
    ) {
        self.client = client
        self.index = index
    }

    func installedModels() async throws -> Set<String> {
        Set(try await client.installedModels())
    }

    func install(model: String) async throws {
        try await client.pull(model: model)
    }

    func enrich(
        _ note: CapturedNote,
        configuration: KnowledgeEngineConfiguration,
        vault: VaultManager
    ) async throws -> KnowledgeEngineOutcome {
        let models = try await installedModels()
        guard Self.contains(configuration.generationModel, in: models) else {
            throw OllamaError.modelMissing(configuration.generationModel)
        }
        guard Self.contains(configuration.embeddingModel, in: models) else {
            throw OllamaError.modelMissing(configuration.embeddingModel)
        }

        let enrichment = try await client.enrich(
            text: note.originalText,
            model: configuration.generationModel,
            customInstructions: configuration.customInstructions
        )
        let queryText = [
            enrichment.title,
            enrichment.summary,
            enrichment.significance,
            enrichment.type.rawValue,
            enrichment.areas.map(\.rawValue).joined(separator: " "),
            enrichment.tags.joined(separator: " "),
            note.originalText
        ].joined(separator: "\n")
        guard let queryVector = try await client.embeddings(
            for: [queryText],
            model: configuration.embeddingModel
        ).first else {
            throw OllamaError.invalidStructuredOutput
        }

        let candidates = try vault.scanNotes(excluding: note.fileURL)
        let related = try await index.relatedIdeas(
            to: queryVector,
            notes: candidates,
            client: client,
            model: configuration.embeddingModel
        )
        let destination = try vault.enrich(
            note,
            enrichment: enrichment,
            related: related,
            model: configuration.generationModel,
            template: configuration.noteTemplate
        )
        if let finalNote = try vault.scanNotes().first(where: { $0.fileURL == destination }) {
            index.upsert(note: finalNote, embedding: queryVector)
        }
        return KnowledgeEngineOutcome(
            title: enrichment.title,
            destination: destination,
            installedModels: models
        )
    }

    private static func contains(_ requested: String, in models: Set<String>) -> Bool {
        models.contains {
            $0 == requested
                || $0.hasPrefix(requested + ":")
                || requested.hasPrefix($0 + ":")
        }
    }
}

/// Runtime services supplied by an edition. The app depends on this protocol,
/// not on licensing or a concrete Pro module.
@MainActor
protocol NelyrFeatureProviding: AnyObject {
    var manifest: NelyrFeatureManifest { get }
    var knowledgeEngine: (any KnowledgeEngine)? { get }
    var dictationCleaner: any DictationCleaning { get }
    var researchRunner: any ResearchRunning { get }
    var researchIsAvailable: Bool { get }
}

@MainActor
final class CommunityFeatureProvider: NelyrFeatureProviding {
    let manifest: NelyrFeatureManifest
    let knowledgeEngine: (any KnowledgeEngine)?
    let dictationCleaner: any DictationCleaning
    let researchRunner: any ResearchRunning
    var researchIsAvailable: Bool {
        FileManager.default.isExecutableFile(atPath: GrokResearchClient.defaultExecutableURL.path)
    }

    init(
        bundle: any NelyrFeatureBundle = NelyrCommunityFeatures(),
        knowledgeEngine: (any KnowledgeEngine)? = LocalKnowledgeEngine(),
        dictationCleaner: any DictationCleaning = OllamaDictationCleaner(),
        researchRunner: any ResearchRunning = GrokResearchClient.shared
    ) {
        self.manifest = bundle.manifest
        self.knowledgeEngine = knowledgeEngine
        self.dictationCleaner = dictationCleaner
        self.researchRunner = researchRunner
    }
}

/// Single composition point for Community and optional Pro implementations.
/// NelyrProKit can call `install` during startup; no feature code needs to know
/// where the implementation came from.
@MainActor
final class FeatureProvider: ObservableObject {
    static let shared = FeatureProvider()

    @Published private(set) var manifest: NelyrFeatureManifest
    private(set) var current: any NelyrFeatureProviding

    init(provider: (any NelyrFeatureProviding)? = nil) {
        let resolved = provider ?? CommunityFeatureProvider()
        current = resolved
        manifest = resolved.manifest
    }

    func install(_ provider: any NelyrFeatureProviding) {
        current = provider
        manifest = provider.manifest
    }

    func supports(_ capability: NelyrCapability) -> Bool {
        manifest.supports(capability)
    }
}
