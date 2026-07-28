import Foundation

@MainActor
final class ResearchController: ObservableObject {
    static let shared = ResearchController()

    @Published private(set) var state: ResearchState = .idle
    @Published private(set) var lastResult: ResearchResult?
    @Published private(set) var currentQuery = ""
    @Published private(set) var liveMarkdown = ""
    @Published private(set) var activeDepth: ResearchDepth = .quick

    private let voice: VoiceDictationController
    private let runner: any ResearchRunning
    private let featureProvider: any NelyrFeatureProviding
    private let vault: VaultManager
    private let settings: DailyDeskSettings
    private var keyIsDown = false
    private var toggleArmed = false
    private var researchTask: Task<Void, Never>?

    init(
        voice: VoiceDictationController = .shared,
        runner: (any ResearchRunning)? = nil,
        vault: VaultManager = .shared,
        settings: DailyDeskSettings = .shared,
        featureProvider: (any NelyrFeatureProviding)? = nil
    ) {
        let resolvedFeatures = featureProvider ?? FeatureProvider.shared.current
        self.voice = voice
        self.runner = runner ?? resolvedFeatures.researchRunner
        self.vault = vault
        self.settings = settings
        self.featureProvider = resolvedFeatures
    }

    var isGrokInstalled: Bool {
        featureProvider.researchIsAvailable
    }

    var isBusy: Bool { state.isBusy }

    func systemwideKeyPressed() {
        guard !keyIsDown, !state.isBusy else { return }
        keyIsDown = true

        switch settings.voiceActivationMode {
        case .hold:
            beginVoiceCapture()
        case .toggle:
            if voice.activeDestination == .research, voice.isRecording {
                toggleArmed = false
                finishVoiceAndResearch()
            } else if toggleArmed {
                cancelVoiceCapture()
            } else {
                toggleArmed = true
                beginVoiceCapture()
            }
        }
    }

    func systemwideKeyReleased() {
        keyIsDown = false
        guard settings.voiceActivationMode == .hold,
              voice.activeDestination == .research,
              voice.isRecording else { return }
        finishVoiceAndResearch()
    }

    func cancelVoiceCapture() {
        guard voice.activeDestination == .research || toggleArmed else { return }
        toggleArmed = false
        keyIsDown = false
        voice.cancel()
    }

    func cancelResearch() {
        guard state.isBusy else { return }
        researchTask?.cancel()
        researchTask = nil
        Task { await runner.cancel() }
        state = .idle
        ResearchStatusPanelController.shared.hide(after: 0)
        ResearchResultPanelController.shared.close()
    }

    func showLastResult() {
        guard lastResult != nil else { return }
        ResearchResultPanelController.shared.show()
    }

    private func beginVoiceCapture() {
        guard vault.vaultURL != nil else {
            fail(ResearchError.vaultNotConfigured.localizedDescription)
            return
        }
        guard isGrokInstalled else {
            fail(ResearchError.grokNotInstalled.localizedDescription)
            return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.voice.beginResearch(shouldContinue: { [weak self] in
                guard let self else { return false }
                return self.settings.voiceActivationMode == .toggle
                    ? self.toggleArmed
                    : self.keyIsDown
            })
            if self.settings.voiceActivationMode == .hold,
               !self.keyIsDown,
               self.voice.activeDestination == .research,
               self.voice.isRecording {
                self.finishVoiceAndResearch()
            }
        }
    }

    private func finishVoiceAndResearch() {
        guard voice.activeDestination == .research, voice.isRecording else { return }
        toggleArmed = false
        Task { @MainActor [weak self] in
            guard let self, let transcription = await self.voice.finishResearch() else { return }
            self.startResearch(query: transcription.text)
        }
    }

    private func startResearch(query: String) {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else {
            fail(VoiceDictationError.emptyTranscript.localizedDescription)
            return
        }
        currentQuery = cleanQuery
        liveMarkdown = ""
        activeDepth = settings.researchDepth
        state = .researching(.starting)
        ResearchStatusPanelController.shared.show()
        ResearchResultPanelController.shared.show()
        let depth = activeDepth

        researchTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let response = try await self.runner.run(
                    query: cleanQuery,
                    depth: depth,
                    onProgress: { [weak self] progress in
                        Task { @MainActor in self?.receive(progress) }
                    }
                )
                try Task.checkCancellation()
                self.receive(.saving)
                let createdAt = Date()
                let id = UUID()
                let fileURL = try self.vault.saveResearch(
                    id: id,
                    createdAt: createdAt,
                    query: cleanQuery,
                    depth: depth,
                    response: response
                )
                self.lastResult = ResearchResult(
                    id: id,
                    createdAt: createdAt,
                    query: cleanQuery,
                    depth: depth,
                    markdown: response.markdown,
                    fileURL: fileURL,
                    sessionID: response.sessionID,
                    requestID: response.requestID,
                    usage: response.usage
                )
                self.state = .completed
                self.researchTask = nil
                ResearchStatusPanelController.shared.hide(after: 1.2)
                ResearchResultPanelController.shared.show()
                NotificationService.shared.sendResearchFinished(query: cleanQuery)
            } catch is CancellationError {
                self.state = .idle
                self.researchTask = nil
                ResearchStatusPanelController.shared.hide(after: 0)
            } catch {
                self.researchTask = nil
                self.fail(error.localizedDescription)
            }
        }
    }

    private func receive(_ progress: ResearchProgress) {
        guard state.isBusy else { return }
        if case .writing(let delta, _) = progress {
            liveMarkdown += delta
        }
        state = .researching(progress)
    }

    private func fail(_ message: String) {
        state = .failed(message)
        toggleArmed = false
        ResearchStatusPanelController.shared.show()
        ResearchStatusPanelController.shared.hide(after: 5)
    }
}
