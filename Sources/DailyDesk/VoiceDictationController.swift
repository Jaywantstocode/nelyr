import AppKit
import Carbon.HIToolbox
import Foundation

@MainActor
final class VoiceDictationController: ObservableObject {
    static let shared = VoiceDictationController()

    @Published private(set) var state: VoiceDictationState = .idle
    @Published private(set) var activeDestination: VoiceDestination?
    @Published private(set) var downloadProgress: Double = 0
    @Published private(set) var lastDetectedLanguage: String?

    private let transcriber: any SpeechTranscribing
    private let recorder: any VoiceRecording
    private let cleaner: any DictationCleaning
    private let inserter: any TextInserting
    private let statusPresenter: any VoiceStatusPresenting
    private let settings: DailyDeskSettings
    private let history: DictationHistoryStore
    private let dictionary: PersonalDictionaryStore
    private var modelReady = false
    private var targetProcessIdentifier: pid_t?
    private var targetContext = DictationAppContext(appName: nil, bundleIdentifier: nil)
    private var selectedTextForEdit: String?
    private var recordingStartedAt: Date?
    private var recordingLimitTask: Task<Void, Never>?
    private var systemwideKeyIsDown = false
    private var systemwideToggleArmed = false
    private var finishInProgress = false
    private var keyRecoveryTask: Task<Void, Never>?
    private var hotKeyRegistrationFailureActive = false

    init(
        transcriber: any SpeechTranscribing = WhisperKitTranscriber.shared,
        recorder: (any VoiceRecording)? = nil,
        cleaner: (any DictationCleaning)? = nil,
        inserter: (any TextInserting)? = nil,
        statusPresenter: (any VoiceStatusPresenting)? = nil,
        settings: DailyDeskSettings = .shared,
        history: DictationHistoryStore = .shared,
        dictionary: PersonalDictionaryStore = .shared,
        featureProvider: (any NelyrFeatureProviding)? = nil
    ) {
        self.transcriber = transcriber
        self.recorder = recorder ?? WhisperAudioRecorder(settings: settings)
        self.cleaner = cleaner
            ?? (featureProvider ?? FeatureProvider.shared.current).dictationCleaner
        self.inserter = inserter ?? SystemTextInserter.shared
        self.statusPresenter = statusPresenter ?? VoiceStatusPanelController.shared
        self.settings = settings
        self.history = history
        self.dictionary = dictionary
    }

    var isRecording: Bool {
        if case .recording = state { return true }
        return false
    }

    var isAccessibilityTrusted: Bool { inserter.isAccessibilityTrusted }

    func prepareInstalledModel() async {
        guard settings.isWhisperModelInstalled,
              !settings.whisperModelPath.isEmpty,
              FileManager.default.fileExists(atPath: settings.whisperModelPath) else {
            modelReady = false
            return
        }
        state = .preparingModel(progress: nil)
        statusPresenter.show()
        do {
            try await transcriber.load(modelFolder: settings.whisperModelPath)
            modelReady = true
            state = .idle
            statusPresenter.hide(after: 0)
        } catch {
            modelReady = false
            settings.isWhisperModelInstalled = false
            settings.whisperModelPath = ""
            fail(error.localizedDescription)
        }
    }

    func installModel() async {
        guard !state.isBusy else { return }
        downloadProgress = 0
        state = .preparingModel(progress: 0)
        statusPresenter.show()
        do {
            let modelPath = try await transcriber.install(model: settings.whisperModel) { progress in
                Task { @MainActor [weak self] in
                    self?.downloadProgress = progress
                    self?.state = .preparingModel(progress: progress)
                }
            }
            settings.whisperModelPath = modelPath
            settings.isWhisperModelInstalled = true
            modelReady = true
            downloadProgress = 1
            state = .completed
            statusPresenter.hide(after: 1.4)
        } catch {
            modelReady = false
            settings.isWhisperModelInstalled = false
            fail("Model installation failed: \(error.localizedDescription)")
        }
    }

    func beginQuickCapture() async {
        await begin(destination: .quickCapture)
    }

    func finishQuickCapture() async -> VoiceTranscription? {
        guard activeDestination == .quickCapture else { return nil }
        return await finishRecording(insertSystemwide: false)
    }

    func beginResearch(shouldContinue: @escaping @MainActor () -> Bool) async {
        await begin(destination: .research, shouldContinue: shouldContinue)
    }

    func finishResearch() async -> VoiceTranscription? {
        guard activeDestination == .research else { return nil }
        return await finishRecording(insertSystemwide: false)
    }

    func systemwideKeyPressed() {
        guard !systemwideKeyIsDown else { return }
        systemwideKeyIsDown = true

        switch settings.voiceActivationMode {
        case .hold:
            monitorPhysicalKeyRelease()
            captureTargetContext()
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.begin(
                    destination: .systemwide,
                    shouldContinue: { [weak self] in self?.shouldContinueSystemwideStart ?? false }
                )
                if !self.systemwideKeyIsDown, self.isRecording {
                    _ = await self.finishRecording(insertSystemwide: true)
                }
            }
        case .toggle:
            recoverToggleKeyStateAfterDelay()
            guard !finishInProgress else { return }
            guard activeDestination == nil || activeDestination == .systemwide else { return }
            if activeDestination == .systemwide, isRecording {
                systemwideToggleArmed = false
                Task { @MainActor [weak self] in
                    _ = await self?.finishRecording(insertSystemwide: true)
                }
            } else if systemwideToggleArmed {
                cancelPendingSystemwideStart()
            } else {
                systemwideToggleArmed = true
                captureTargetContext()
                Task { @MainActor [weak self] in
                    await self?.begin(
                        destination: .systemwide,
                        shouldContinue: { [weak self] in self?.shouldContinueSystemwideStart ?? false }
                    )
                }
            }
        }
    }

    func translationKeyPressed() {
        toggleSpecialMode(.translation)
    }

    func voiceEditKeyPressed() {
        if activeDestination == nil {
            captureTargetContext()
            guard let selection = inserter.selectedText() else {
                fail("Select some editable text first, then use Voice Edit.")
                return
            }
            selectedTextForEdit = selection
        }
        toggleSpecialMode(.voiceEdit)
    }

    func systemwideKeyReleased() {
        systemwideKeyIsDown = false
        keyRecoveryTask?.cancel()
        guard settings.voiceActivationMode == .hold else { return }
        guard activeDestination == .systemwide, isRecording else { return }
        Task { @MainActor [weak self] in
            _ = await self?.finishRecording(insertSystemwide: true)
        }
    }

    func cancel() {
        guard activeDestination != nil || state.isBusy else { return }
        recorder.cancel()
        recordingLimitTask?.cancel()
        keyRecoveryTask?.cancel()
        activeDestination = nil
        systemwideKeyIsDown = false
        systemwideToggleArmed = false
        finishInProgress = false
        selectedTextForEdit = nil
        state = .idle
        statusPresenter.hide(after: 0)
    }

    func requestAccessibility() {
        inserter.requestAccessibility()
    }

    func cancelStaleShortcutState() {
        keyRecoveryTask?.cancel()
        systemwideKeyIsDown = false
        systemwideToggleArmed = false
    }

    func reportHotKeyRegistrationFailure() {
        hotKeyRegistrationFailureActive = true
        fail("The dictation shortcut could not be registered. It may already be used by macOS or another app. Choose another shortcut in Settings → Voice.")
    }

    func reportHotKeyRegistrationSuccess() {
        guard hotKeyRegistrationFailureActive else { return }
        hotKeyRegistrationFailureActive = false
        if case .failed = state {
            state = .idle
            statusPresenter.hide(after: 0)
        }
    }

    private func begin(
        destination: VoiceDestination,
        shouldContinue: @escaping @MainActor () -> Bool = { true }
    ) async {
        guard activeDestination == nil, !finishInProgress else { return }
        guard settings.isWhisperModelInstalled, !settings.whisperModelPath.isEmpty else {
            state = .needsModel
            statusPresenter.show()
            statusPresenter.hide(after: 3)
            return
        }
        if !modelReady {
            state = .preparingModel(progress: nil)
            statusPresenter.show()
            do {
                try await transcriber.load(modelFolder: settings.whisperModelPath)
                modelReady = true
            } catch {
                settings.isWhisperModelInstalled = false
                settings.whisperModelPath = ""
                fail(error.localizedDescription)
                return
            }
        }
        guard shouldContinue() else {
            abortPendingBegin()
            return
        }
        guard await recorder.requestPermission() else {
            fail(VoiceDictationError.microphoneDenied.localizedDescription)
            return
        }
        guard shouldContinue() else {
            abortPendingBegin()
            return
        }
        do {
            try recorder.start()
            activeDestination = destination
            let startedAt = Date()
            recordingStartedAt = startedAt
            state = .recording(startedAt: startedAt)
            playSound(named: "Tink")
            scheduleRecordingLimit(for: destination)
            statusPresenter.show()
        } catch {
            fail(error.localizedDescription)
        }
    }

    private func finishRecording(insertSystemwide: Bool) async -> VoiceTranscription? {
        guard !finishInProgress, let destination = activeDestination else { return nil }
        finishInProgress = true
        recordingLimitTask?.cancel()
        if insertSystemwide || destination == .translation || destination == .voiceEdit { systemwideToggleArmed = false }
        let startedAt = recordingStartedAt
        let context = targetContext
        let selectedText = selectedTextForEdit
        let samples = recorder.stop()
        activeDestination = nil
        selectedTextForEdit = nil
        playSound(named: "Pop")
        state = .transcribing
        statusPresenter.show()
        defer { finishInProgress = false }

        do {
            let transcription = try await transcriber.transcribe(samples: samples)
            lastDetectedLanguage = transcription.detectedLanguage
            guard insertSystemwide || destination == .translation || destination == .voiceEdit else {
                state = .completed
                statusPresenter.hide(after: 1)
                return transcription
            }

            var output: String
            switch destination {
            case .translation:
                state = .cleaning
                output = try await cleaner.translate(
                    transcription.text,
                    target: settings.translationTarget,
                    model: settings.generationModel,
                    dictionary: dictionary.terms
                )
            case .voiceEdit:
                guard let selectedText else {
                    throw VoiceDictationError.noSelectedText
                }
                state = .cleaning
                output = try await cleaner.edit(
                    selectedText: selectedText,
                    instruction: transcription.text,
                    model: settings.generationModel,
                    context: context,
                    dictionary: dictionary.terms
                )
            default:
                output = transcription.text
                if settings.voiceCleanupMode != .none {
                    state = .cleaning
                    if let cleaned = try? await cleaner.clean(
                        transcription.text,
                        mode: settings.voiceCleanupMode,
                        model: settings.generationModel,
                        detectedLanguage: transcription.detectedLanguage,
                        context: settings.appAwareDictation ? context : DictationAppContext(appName: nil, bundleIdentifier: nil),
                        dictionary: dictionary.terms,
                        customStyle: settings.customWritingStyle
                    ), !cleaned.isEmpty,
                       DictationLanguageGuard.accepts(
                        cleaned: cleaned,
                        source: transcription.text,
                        detectedLanguage: transcription.detectedLanguage
                       ) {
                        output = cleaned
                    }
                }
            }
            state = .inserting
            let insertion = inserter.insert(
                output,
                into: targetProcessIdentifier,
                directly: settings.directVoiceInsertion
            )
            switch insertion {
            case .inserted:
                state = .completed
            case .copied:
                state = .copied
            case .secureField:
                state = .failed("Secure field detected — copied, not inserted.")
            }
            history.add(
                DictationHistoryItem(
                    id: UUID(),
                    createdAt: Date(),
                    rawText: transcription.text,
                    outputText: output,
                    detectedLanguage: transcription.detectedLanguage,
                    duration: startedAt.map { Date().timeIntervalSince($0) } ?? 0,
                    mode: historyMode(for: destination),
                    appContext: context
                ),
                retention: settings.voiceHistoryRetention
            )
            statusPresenter.hide(after: insertion == .inserted ? 1 : 3)
            return VoiceTranscription(text: output, detectedLanguage: transcription.detectedLanguage)
        } catch {
            fail(error.localizedDescription)
            return nil
        }
    }

    private func fail(_ message: String) {
        state = .failed(message)
        activeDestination = nil
        systemwideToggleArmed = false
        finishInProgress = false
        statusPresenter.show()
        statusPresenter.hide(after: 4)
    }

    private func toggleSpecialMode(_ destination: VoiceDestination) {
        if activeDestination == destination, isRecording {
            Task { @MainActor [weak self] in
                _ = await self?.finishRecording(insertSystemwide: true)
            }
            return
        }
        guard activeDestination == nil, !state.isBusy else { return }
        if destination == .translation { captureTargetContext() }
        Task { @MainActor [weak self] in
            await self?.begin(destination: destination)
        }
    }

    private func captureTargetContext() {
        let app = NSWorkspace.shared.frontmostApplication
        targetProcessIdentifier = app?.processIdentifier
        targetContext = DictationAppContext(
            appName: app?.localizedName,
            bundleIdentifier: app?.bundleIdentifier
        )
    }

    private func scheduleRecordingLimit(for destination: VoiceDestination) {
        recordingLimitTask?.cancel()
        recordingLimitTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(9 * 60))
            guard !Task.isCancelled, let self, self.activeDestination == destination else { return }
            _ = await self.finishRecording(insertSystemwide: destination != .quickCapture && destination != .research)
        }
    }

    private func historyMode(for destination: VoiceDestination) -> DictationHistoryItem.Mode {
        switch destination {
        case .translation: .translation
        case .voiceEdit: .voiceEdit
        default: .dictation
        }
    }

    private func playSound(named name: NSSound.Name) {
        guard settings.interactionSounds else { return }
        NSSound(named: name)?.play()
    }

    private func recoverToggleKeyStateAfterDelay() {
        keyRecoveryTask?.cancel()
        keyRecoveryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled, let self, self.settings.voiceActivationMode == .toggle else { return }
            self.systemwideKeyIsDown = false
        }
    }

    private func monitorPhysicalKeyRelease() {
        keyRecoveryTask?.cancel()
        keyRecoveryTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(120))
                guard !Task.isCancelled, let self,
                      self.settings.voiceActivationMode == .hold,
                      self.systemwideKeyIsDown else { return }
                guard CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(kVK_Space)) else {
                    self.systemwideKeyReleased()
                    return
                }
            }
        }
    }

    private var shouldContinueSystemwideStart: Bool {
        switch settings.voiceActivationMode {
        case .hold: systemwideKeyIsDown
        case .toggle: systemwideToggleArmed
        }
    }

    private func cancelPendingSystemwideStart() {
        systemwideToggleArmed = false
        activeDestination = nil
        recorder.cancel()
        state = .idle
        statusPresenter.hide(after: 0)
    }

    private func abortPendingBegin() {
        guard activeDestination == nil else { return }
        state = .idle
        statusPresenter.hide(after: 0)
    }
}
