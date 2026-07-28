@preconcurrency import WhisperKit
import Foundation

actor WhisperKitTranscriber: SpeechTranscribing {
    static let shared = WhisperKitTranscriber()

    private var whisperKit: WhisperKit?

    func install(
        model: String,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> String {
        let base = try modelDownloadDirectory()
        progress(0)
        let folder = try await WhisperKit.download(
            variant: model,
            downloadBase: base
        ) { downloadProgress in
            progress(min(downloadProgress.fractionCompleted * 0.9, 0.9))
        }
        progress(0.92)
        whisperKit = try await makeWhisperKit(modelFolder: folder.path, downloadBase: base)
        progress(1)
        return folder.path
    }

    func load(modelFolder: String) async throws {
        let base = try modelDownloadDirectory()
        whisperKit = try await makeWhisperKit(modelFolder: modelFolder, downloadBase: base)
    }

    func transcribe(samples: [Float]) async throws -> VoiceTranscription {
        guard let whisperKit else { throw VoiceDictationError.modelNotInstalled }
        guard samples.count >= WhisperKit.sampleRate / 5 else {
            throw VoiceDictationError.emptyRecording
        }

        let options = DecodingOptions(
            task: .transcribe,
            language: nil,
            usePrefillPrompt: false,
            detectLanguage: true,
            wordTimestamps: false,
            chunkingStrategy: .vad
        )
        let results: [TranscriptionResult] = try await whisperKit.transcribe(
            audioArray: samples,
            decodeOptions: options
        )
        let text = results
            .map(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw VoiceDictationError.emptyTranscript }
        return VoiceTranscription(text: text, detectedLanguage: results.first?.language)
    }

    private func makeWhisperKit(modelFolder: String, downloadBase: URL) async throws -> WhisperKit {
        let config = WhisperKitConfig(
            downloadBase: downloadBase,
            modelFolder: modelFolder,
            tokenizerFolder: downloadBase,
            verbose: false,
            prewarm: false,
            load: true,
            download: false
        )
        return try await WhisperKit(config)
    }

    private func modelDownloadDirectory() throws -> URL {
        let applicationSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = applicationSupport
            .appendingPathComponent("DailyDesk", isDirectory: true)
            .appendingPathComponent("WhisperModels", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
