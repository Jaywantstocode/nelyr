import Foundation

struct OllamaDictationCleaner: DictationCleaning {
    let client: OllamaClient

    init(client: OllamaClient = OllamaClient()) {
        self.client = client
    }

    func clean(
        _ transcript: String,
        mode: VoiceCleanupMode,
        model: String,
        detectedLanguage: String?,
        context: DictationAppContext,
        dictionary: [String],
        customStyle: String
    ) async throws -> String {
        try await client.cleanDictation(
            transcript,
            mode: mode,
            model: model,
            detectedLanguage: detectedLanguage,
            context: context,
            dictionary: dictionary,
            customStyle: customStyle
        )
    }

    func translate(
        _ transcript: String,
        target: TranslationTarget,
        model: String,
        dictionary: [String]
    ) async throws -> String {
        try await client.translateDictation(transcript, target: target, model: model, dictionary: dictionary)
    }

    func edit(
        selectedText: String,
        instruction: String,
        model: String,
        context: DictationAppContext,
        dictionary: [String]
    ) async throws -> String {
        try await client.editSelectedText(
            selectedText,
            instruction: instruction,
            model: model,
            context: context,
            dictionary: dictionary
        )
    }
}
