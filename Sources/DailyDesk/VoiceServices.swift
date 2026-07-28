import Foundation

protocol SpeechTranscribing: Sendable {
    func install(model: String, progress: @escaping @Sendable (Double) -> Void) async throws -> String
    func load(modelFolder: String) async throws
    func transcribe(samples: [Float]) async throws -> VoiceTranscription
}

@MainActor
protocol VoiceRecording: AnyObject {
    func requestPermission() async -> Bool
    func start() throws
    func stop() -> [Float]
    func cancel()
}

protocol DictationCleaning: Sendable {
    func clean(
        _ transcript: String,
        mode: VoiceCleanupMode,
        model: String,
        detectedLanguage: String?,
        context: DictationAppContext,
        dictionary: [String],
        customStyle: String
    ) async throws -> String
    func translate(
        _ transcript: String,
        target: TranslationTarget,
        model: String,
        dictionary: [String]
    ) async throws -> String
    func edit(
        selectedText: String,
        instruction: String,
        model: String,
        context: DictationAppContext,
        dictionary: [String]
    ) async throws -> String
}

enum TextInsertionResult: Equatable, Sendable {
    case inserted
    case copied
    case secureField
}

@MainActor
protocol TextInserting: AnyObject {
    var isAccessibilityTrusted: Bool { get }
    func requestAccessibility()
    func selectedText() -> String?
    func insert(_ text: String, into processIdentifier: pid_t?, directly: Bool) -> TextInsertionResult
}

@MainActor
protocol VoiceStatusPresenting: AnyObject {
    func show()
    func hide(after delay: TimeInterval)
}
