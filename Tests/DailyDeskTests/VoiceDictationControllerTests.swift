import Foundation
import XCTest
@testable import Nelyr

@MainActor
final class VoiceDictationControllerTests: XCTestCase {
    func testQuickCapturePreservesRawMultilingualTranscript() async throws {
        let (settings, defaults, suite) = makeSettings(modelInstalled: true)
        defer { defaults.removePersistentDomain(forName: suite) }
        let recorder = FakeVoiceRecorder(samples: [Float](repeating: 0.25, count: 4_000))
        let inserter = FakeTextInserter(result: .inserted)
        let controller = VoiceDictationController(
            transcriber: FakeSpeechTranscriber(
                result: VoiceTranscription(text: "明日は Toronto に行きたい。", detectedLanguage: "ja")
            ),
            recorder: recorder,
            cleaner: FakeDictationCleaner(output: "should not be used"),
            inserter: inserter,
            statusPresenter: FakeVoiceStatusPresenter(),
            settings: settings
        )

        await controller.beginQuickCapture()
        XCTAssertTrue(controller.isRecording)
        XCTAssertEqual(controller.activeDestination, .quickCapture)

        let result = await controller.finishQuickCapture()

        XCTAssertEqual(result?.text, "明日は Toronto に行きたい。")
        XCTAssertEqual(result?.detectedLanguage, "ja")
        XCTAssertEqual(controller.lastDetectedLanguage, "ja")
        XCTAssertEqual(controller.state, .completed)
        XCTAssertEqual(inserter.insertCallCount, 0)
        XCTAssertEqual(recorder.stopCallCount, 1)
    }

    func testMissingModelDoesNotRequestMicrophoneOrRecord() async {
        let (settings, defaults, suite) = makeSettings(modelInstalled: false)
        defer { defaults.removePersistentDomain(forName: suite) }
        let recorder = FakeVoiceRecorder(samples: [])
        let controller = VoiceDictationController(
            transcriber: FakeSpeechTranscriber(
                result: VoiceTranscription(text: "unused", detectedLanguage: "en")
            ),
            recorder: recorder,
            cleaner: FakeDictationCleaner(output: "unused"),
            inserter: FakeTextInserter(result: .copied),
            statusPresenter: FakeVoiceStatusPresenter(),
            settings: settings
        )

        await controller.beginQuickCapture()

        XCTAssertEqual(controller.state, .needsModel)
        XCTAssertFalse(recorder.permissionRequested)
        XCTAssertFalse(recorder.started)
    }

    func testModelInstallationPersistsDownloadedFolder() async {
        let (settings, defaults, suite) = makeSettings(modelInstalled: false)
        defer { defaults.removePersistentDomain(forName: suite) }
        let controller = VoiceDictationController(
            transcriber: FakeSpeechTranscriber(
                result: VoiceTranscription(text: "unused", detectedLanguage: "en")
            ),
            recorder: FakeVoiceRecorder(samples: []),
            cleaner: FakeDictationCleaner(output: "unused"),
            inserter: FakeTextInserter(result: .copied),
            statusPresenter: FakeVoiceStatusPresenter(),
            settings: settings
        )

        await controller.installModel()

        XCTAssertTrue(settings.isWhisperModelInstalled)
        XCTAssertEqual(settings.whisperModelPath, FileManager.default.temporaryDirectory.path)
        XCTAssertEqual(controller.downloadProgress, 1)
        XCTAssertEqual(controller.state, .completed)
    }

    func testToggleModeRecordsAcrossKeyReleaseAndStopsOnNextPress() async {
        let (settings, defaults, suite) = makeSettings(modelInstalled: true)
        defer { defaults.removePersistentDomain(forName: suite) }
        settings.voiceActivationMode = .toggle
        let recorder = FakeVoiceRecorder(samples: [Float](repeating: 0.25, count: 4_000))
        let inserter = FakeTextInserter(result: .inserted)
        let history = DictationHistoryStore(storageURL: temporaryJSON("history"))
        let dictionary = PersonalDictionaryStore(storageURL: temporaryJSON("dictionary"))
        let controller = VoiceDictationController(
            transcriber: FakeSpeechTranscriber(
                result: VoiceTranscription(text: "toggle mode works", detectedLanguage: "en")
            ),
            recorder: recorder,
            cleaner: FakeDictationCleaner(output: "toggle mode works"),
            inserter: inserter,
            statusPresenter: FakeVoiceStatusPresenter(),
            settings: settings,
            history: history,
            dictionary: dictionary
        )

        controller.systemwideKeyPressed()
        await waitForTasks()
        controller.systemwideKeyReleased()

        XCTAssertTrue(controller.isRecording)
        XCTAssertEqual(recorder.stopCallCount, 0)

        controller.systemwideKeyPressed()
        controller.systemwideKeyReleased()
        await waitForTasks()

        XCTAssertFalse(controller.isRecording)
        XCTAssertEqual(recorder.stopCallCount, 1)
        XCTAssertEqual(inserter.insertCallCount, 1)
        XCTAssertEqual(controller.state, .completed)
    }

    func testToggleModeRecoversWhenHotKeyReleaseEventIsMissed() async {
        let (settings, defaults, suite) = makeSettings(modelInstalled: true)
        defer { defaults.removePersistentDomain(forName: suite) }
        settings.voiceActivationMode = .toggle
        let recorder = FakeVoiceRecorder(samples: [Float](repeating: 0.25, count: 4_000))
        let controller = VoiceDictationController(
            transcriber: FakeSpeechTranscriber(result: VoiceTranscription(text: "recovered", detectedLanguage: "en")),
            recorder: recorder,
            cleaner: FakeDictationCleaner(output: "recovered"),
            inserter: FakeTextInserter(result: .inserted),
            statusPresenter: FakeVoiceStatusPresenter(),
            settings: settings,
            history: DictationHistoryStore(storageURL: temporaryJSON("history")),
            dictionary: PersonalDictionaryStore(storageURL: temporaryJSON("dictionary"))
        )

        controller.systemwideKeyPressed()
        await waitForTasks()
        XCTAssertTrue(controller.isRecording)

        try? await Task.sleep(for: .milliseconds(250))
        controller.systemwideKeyPressed()
        await waitForTasks()

        XCTAssertFalse(controller.isRecording)
        XCTAssertEqual(recorder.stopCallCount, 1)
    }

    func testPressDuringTranscriptionDoesNotPoisonNextToggle() async {
        let (settings, defaults, suite) = makeSettings(modelInstalled: true)
        defer { defaults.removePersistentDomain(forName: suite) }
        settings.voiceActivationMode = .toggle
        let recorder = FakeVoiceRecorder(samples: [Float](repeating: 0.25, count: 4_000))
        let controller = VoiceDictationController(
            transcriber: FakeSpeechTranscriber(
                result: VoiceTranscription(text: "slow result", detectedLanguage: "en"),
                delayMilliseconds: 140
            ),
            recorder: recorder,
            cleaner: FakeDictationCleaner(output: "slow result"),
            inserter: FakeTextInserter(result: .inserted),
            statusPresenter: FakeVoiceStatusPresenter(),
            settings: settings,
            history: DictationHistoryStore(storageURL: temporaryJSON("history")),
            dictionary: PersonalDictionaryStore(storageURL: temporaryJSON("dictionary"))
        )

        controller.systemwideKeyPressed()
        controller.systemwideKeyReleased()
        await waitForTasks()
        controller.systemwideKeyPressed()
        controller.systemwideKeyReleased()
        try? await Task.sleep(for: .milliseconds(20))

        controller.systemwideKeyPressed()
        controller.systemwideKeyReleased()
        try? await Task.sleep(for: .milliseconds(180))

        controller.systemwideKeyPressed()
        controller.systemwideKeyReleased()
        await waitForTasks()
        XCTAssertTrue(controller.isRecording)
    }

    func testHoldModeStopsWhenShortcutIsReleased() async {
        let (settings, defaults, suite) = makeSettings(modelInstalled: true)
        defer { defaults.removePersistentDomain(forName: suite) }
        settings.voiceActivationMode = .hold
        let recorder = FakeVoiceRecorder(samples: [Float](repeating: 0.25, count: 4_000))
        let inserter = FakeTextInserter(result: .inserted)
        let history = DictationHistoryStore(storageURL: temporaryJSON("history"))
        let dictionary = PersonalDictionaryStore(storageURL: temporaryJSON("dictionary"))
        let controller = VoiceDictationController(
            transcriber: FakeSpeechTranscriber(
                result: VoiceTranscription(text: "hold mode works", detectedLanguage: "en")
            ),
            recorder: recorder,
            cleaner: FakeDictationCleaner(output: "hold mode works"),
            inserter: inserter,
            statusPresenter: FakeVoiceStatusPresenter(),
            settings: settings,
            history: history,
            dictionary: dictionary
        )

        controller.systemwideKeyPressed()
        await waitForTasks()
        XCTAssertTrue(controller.isRecording)

        controller.systemwideKeyReleased()
        await waitForTasks()

        XCTAssertEqual(recorder.stopCallCount, 1)
        XCTAssertEqual(inserter.insertCallCount, 1)
        XCTAssertEqual(controller.state, .completed)
    }

    func testTranslationAndVoiceEditUseLocalCleanerAndSaveHistory() async {
        let (settings, defaults, suite) = makeSettings(modelInstalled: true)
        defer { defaults.removePersistentDomain(forName: suite) }
        let history = DictationHistoryStore(storageURL: temporaryJSON("history"))
        let dictionary = PersonalDictionaryStore(storageURL: temporaryJSON("dictionary"))
        XCTAssertTrue(dictionary.add("Daily Desk"))
        let inserter = FakeTextInserter(result: .inserted)
        let controller = VoiceDictationController(
            transcriber: FakeSpeechTranscriber(
                result: VoiceTranscription(text: "もっと暖かくして", detectedLanguage: "ja")
            ),
            recorder: FakeVoiceRecorder(samples: [Float](repeating: 0.25, count: 4_000)),
            cleaner: FakeDictationCleaner(output: "A warmer version"),
            inserter: inserter,
            statusPresenter: FakeVoiceStatusPresenter(),
            settings: settings,
            history: history,
            dictionary: dictionary
        )

        controller.translationKeyPressed()
        await waitForTasks()
        controller.translationKeyPressed()
        await waitForTasks()
        XCTAssertEqual(history.items.first?.mode, .translation)
        XCTAssertEqual(history.items.first?.outputText, "A warmer version")

        controller.voiceEditKeyPressed()
        await waitForTasks()
        controller.voiceEditKeyPressed()
        await waitForTasks()
        XCTAssertEqual(history.items.first?.mode, .voiceEdit)
        XCTAssertEqual(inserter.insertCallCount, 2)
    }

    private func makeSettings(
        modelInstalled: Bool
    ) -> (DailyDeskSettings, UserDefaults, String) {
        let suite = "VoiceDictationControllerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let settings = DailyDeskSettings(defaults: defaults)
        settings.whisperModelPath = modelInstalled ? FileManager.default.temporaryDirectory.path : ""
        settings.isWhisperModelInstalled = modelInstalled
        settings.interactionSounds = false
        return (settings, defaults, suite)
    }

    private func temporaryJSON(_ name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("DailyDeskTests-\(name)-\(UUID().uuidString).json")
    }

    private func waitForTasks() async {
        try? await Task.sleep(for: .milliseconds(30))
    }
}

private actor FakeSpeechTranscriber: SpeechTranscribing {
    let result: VoiceTranscription
    let delayMilliseconds: Int

    init(result: VoiceTranscription, delayMilliseconds: Int = 0) {
        self.result = result
        self.delayMilliseconds = delayMilliseconds
    }

    func install(model: String, progress: @escaping @Sendable (Double) -> Void) async throws -> String {
        progress(0.5)
        progress(1)
        return FileManager.default.temporaryDirectory.path
    }

    func load(modelFolder: String) async throws {}

    func transcribe(samples: [Float]) async throws -> VoiceTranscription {
        if delayMilliseconds > 0 {
            try? await Task.sleep(for: .milliseconds(delayMilliseconds))
        }
        return result
    }
}

@MainActor
private final class FakeVoiceRecorder: VoiceRecording {
    let samples: [Float]
    var permissionRequested = false
    var started = false
    var stopCallCount = 0

    init(samples: [Float]) {
        self.samples = samples
    }

    func requestPermission() async -> Bool {
        permissionRequested = true
        return true
    }

    func start() throws { started = true }

    func stop() -> [Float] {
        stopCallCount += 1
        started = false
        return samples
    }

    func cancel() { started = false }
}

private struct FakeDictationCleaner: DictationCleaning {
    let output: String

    func clean(
        _ transcript: String,
        mode: VoiceCleanupMode,
        model: String,
        detectedLanguage: String?,
        context: DictationAppContext,
        dictionary: [String],
        customStyle: String
    ) async throws -> String {
        output
    }

    func translate(
        _ transcript: String,
        target: TranslationTarget,
        model: String,
        dictionary: [String]
    ) async throws -> String { output }

    func edit(
        selectedText: String,
        instruction: String,
        model: String,
        context: DictationAppContext,
        dictionary: [String]
    ) async throws -> String { output }
}

@MainActor
private final class FakeTextInserter: TextInserting {
    let result: TextInsertionResult
    var insertCallCount = 0
    var isAccessibilityTrusted = true

    init(result: TextInsertionResult) {
        self.result = result
    }

    func requestAccessibility() {}

    func selectedText() -> String? { "Selected text" }

    func insert(_ text: String, into processIdentifier: pid_t?, directly: Bool) -> TextInsertionResult {
        insertCallCount += 1
        return result
    }
}

@MainActor
private final class FakeVoiceStatusPresenter: VoiceStatusPresenting {
    func show() {}
    func hide(after delay: TimeInterval) {}
}
