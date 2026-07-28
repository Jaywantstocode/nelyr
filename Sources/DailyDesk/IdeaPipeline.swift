import Foundation

@MainActor
final class IdeaPipeline: ObservableObject {
    static let shared = IdeaPipeline()

    enum Phase: Equatable {
        case idle
        case needsVault
        case checkingOllama
        case installing(String)
        case processing
        case completed(String)
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var installedModels: Set<String> = []
    @Published private(set) var pendingCount = 0
    @Published private(set) var ollamaAvailable = false

    private let knowledgeEngine: (any KnowledgeEngine)?
    private let vault: VaultManager
    private let settings: DailyDeskSettings
    private var retryQueue: [CapturedNote] = []

    init(
        featureProvider: (any NelyrFeatureProviding)? = nil,
        vault: VaultManager = .shared,
        settings: DailyDeskSettings = .shared
    ) {
        self.knowledgeEngine = (featureProvider ?? FeatureProvider.shared.current).knowledgeEngine
        self.vault = vault
        self.settings = settings
    }

    func checkOllama() async {
        guard let knowledgeEngine else {
            installedModels = []
            ollamaAvailable = false
            phase = .idle
            return
        }
        phase = .checkingOllama
        do {
            installedModels = try await knowledgeEngine.installedModels()
            ollamaAvailable = true
            phase = .idle
        } catch {
            ollamaAvailable = false
            phase = .failed("Ollama is not running. Captures will still be saved.")
        }
    }

    func installRequiredModels() async {
        guard let knowledgeEngine else {
            phase = .completed("Saved locally without enrichment")
            return
        }
        phase = .installing(settings.generationModel)
        do {
            try await knowledgeEngine.install(model: settings.generationModel)
            phase = .installing(settings.embeddingModel)
            try await knowledgeEngine.install(model: settings.embeddingModel)
            await checkOllama()
        } catch {
            phase = .failed("Could not install local models: \(error.localizedDescription)")
        }
    }

    @discardableResult
    func capture(_ raw: String) -> Bool {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        guard vault.vaultURL != nil else {
            phase = .needsVault
            return false
        }
        do {
            let note = try vault.capture(text, template: settings.noteTemplate)
            queueForEnrichment(note)
            return true
        } catch {
            phase = .failed(error.localizedDescription)
            return false
        }
    }

    @discardableResult
    func captureScreenshot(context: String, recognizedText: String, pngData: Data) -> Bool {
        guard vault.vaultURL != nil else {
            phase = .needsVault
            return false
        }
        do {
            let note = try vault.captureScreenshot(
                context: context,
                recognizedText: recognizedText,
                pngData: pngData,
                template: settings.noteTemplate
            )
            queueForEnrichment(note)
            return true
        } catch {
            phase = .failed(error.localizedDescription)
            return false
        }
    }

    func retryPending() {
        guard knowledgeEngine != nil else { return }
        let notes = retryQueue
        guard !notes.isEmpty else { return }
        phase = .processing
        for note in notes {
            Task { [weak self] in await self?.enrich(note) }
        }
    }

    private func queueForEnrichment(_ note: CapturedNote) {
        guard knowledgeEngine != nil else {
            phase = .completed("Saved locally")
            return
        }
        retryQueue.append(note)
        pendingCount += 1
        phase = .processing
        Task { [weak self] in await self?.enrich(note) }
    }

    private func enrich(_ note: CapturedNote) async {
        guard let knowledgeEngine else { return }
        do {
            let result = try await knowledgeEngine.enrich(
                note,
                configuration: KnowledgeEngineConfiguration(
                    generationModel: settings.generationModel,
                    embeddingModel: settings.embeddingModel,
                    customInstructions: settings.customAIInstructions,
                    noteTemplate: settings.noteTemplate
                ),
                vault: vault
            )
            installedModels = result.installedModels
            ollamaAvailable = true
            retryQueue.removeAll { $0.id == note.id }
            pendingCount = max(0, pendingCount - 1)
            phase = .completed(result.title)
        } catch {
            ollamaAvailable = !(error is URLError)
            phase = .failed(error.localizedDescription)
        }
    }
}
