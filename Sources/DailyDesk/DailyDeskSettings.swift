import Foundation

@MainActor
final class DailyDeskSettings: ObservableObject {
    static let shared = DailyDeskSettings()

    static let defaultAIInstructions = "Preserve the user's exact intent. Classify the capture across their whole life, not just work or business. Be neutral and specific. Do not diagnose, invent emotions, add motivational filler, or force an action when none is naturally implied."
    private static let legacyAIInstructions = "Preserve the user's intent. Prefer specific, reusable topic tags. Do not add motivational filler."

    @Published var generationModel: String {
        didSet { defaults.set(generationModel, forKey: Keys.generationModel) }
    }
    @Published var embeddingModel: String {
        didSet { defaults.set(embeddingModel, forKey: Keys.embeddingModel) }
    }
    @Published var customAIInstructions: String {
        didSet { defaults.set(customAIInstructions, forKey: Keys.customInstructions) }
    }
    @Published var noteTemplate: String {
        didSet {
            if IdeaTemplateRenderer.isValidTemplate(noteTemplate) {
                defaults.set(noteTemplate, forKey: Keys.noteTemplate)
            }
        }
    }
    @Published var morningHour: Int {
        didSet { defaults.set(morningHour, forKey: Keys.morningHour) }
    }
    @Published var morningMinute: Int {
        didSet { defaults.set(morningMinute, forKey: Keys.morningMinute) }
    }
    @Published var whisperModel: String {
        didSet {
            defaults.set(whisperModel, forKey: Keys.whisperModel)
            if whisperModel != oldValue {
                isWhisperModelInstalled = false
                whisperModelPath = ""
            }
        }
    }
    @Published var voiceCleanupMode: VoiceCleanupMode {
        didSet { defaults.set(voiceCleanupMode.rawValue, forKey: Keys.voiceCleanupMode) }
    }
    @Published var voiceActivationMode: VoiceActivationMode {
        didSet { defaults.set(voiceActivationMode.rawValue, forKey: Keys.voiceActivationMode) }
    }
    @Published var directVoiceInsertion: Bool {
        didSet { defaults.set(directVoiceInsertion, forKey: Keys.directVoiceInsertion) }
    }
    @Published var isWhisperModelInstalled: Bool {
        didSet { defaults.set(isWhisperModelInstalled, forKey: Keys.isWhisperModelInstalled) }
    }
    @Published var whisperModelPath: String {
        didSet { defaults.set(whisperModelPath, forKey: Keys.whisperModelPath) }
    }
    @Published var voiceDictationShortcut: VoiceDictationShortcut {
        didSet {
            defaults.set(voiceDictationShortcut.rawValue, forKey: Keys.voiceDictationShortcut)
            NotificationCenter.default.post(name: .voiceShortcutChanged, object: nil)
        }
    }
    @Published var researchDepth: ResearchDepth {
        didSet { defaults.set(researchDepth.rawValue, forKey: Keys.researchDepth) }
    }
    @Published var researchDictationShortcut: ResearchDictationShortcut {
        didSet {
            defaults.set(researchDictationShortcut.rawValue, forKey: Keys.researchDictationShortcut)
            NotificationCenter.default.post(name: .researchShortcutChanged, object: nil)
        }
    }
    @Published var translationDictationShortcut: TranslationDictationShortcut {
        didSet {
            defaults.set(translationDictationShortcut.rawValue, forKey: Keys.translationDictationShortcut)
            NotificationCenter.default.post(name: .translationShortcutChanged, object: nil)
        }
    }
    @Published var voiceEditShortcut: VoiceEditShortcut {
        didSet {
            defaults.set(voiceEditShortcut.rawValue, forKey: Keys.voiceEditShortcut)
            NotificationCenter.default.post(name: .voiceEditShortcutChanged, object: nil)
        }
    }
    @Published var translationTarget: TranslationTarget {
        didSet { defaults.set(translationTarget.rawValue, forKey: Keys.translationTarget) }
    }
    @Published var voiceHistoryRetention: VoiceHistoryRetention {
        didSet {
            defaults.set(voiceHistoryRetention.rawValue, forKey: Keys.voiceHistoryRetention)
            DictationHistoryStore.shared.apply(retention: voiceHistoryRetention)
        }
    }
    @Published var appAwareDictation: Bool {
        didSet { defaults.set(appAwareDictation, forKey: Keys.appAwareDictation) }
    }
    @Published var interactionSounds: Bool {
        didSet { defaults.set(interactionSounds, forKey: Keys.interactionSounds) }
    }
    @Published var customWritingStyle: String {
        didSet { defaults.set(customWritingStyle, forKey: Keys.customWritingStyle) }
    }
    @Published var microphoneDeviceID: UInt32 {
        didSet { defaults.set(Int(microphoneDeviceID), forKey: Keys.microphoneDeviceID) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        generationModel = defaults.string(forKey: Keys.generationModel) ?? "gemma3:12b"
        embeddingModel = defaults.string(forKey: Keys.embeddingModel) ?? "embeddinggemma"
        let storedInstructions = defaults.string(forKey: Keys.customInstructions)
        customAIInstructions = storedInstructions == Self.legacyAIInstructions || storedInstructions == nil
            ? Self.defaultAIInstructions
            : storedInstructions!
        let storedTemplate = defaults.string(forKey: Keys.noteTemplate)
        let usesBuiltInTemplate = storedTemplate == IdeaTemplateRenderer.legacyDefaultTemplate
            || storedTemplate == IdeaTemplateRenderer.previousDefaultTemplate
            || storedTemplate == nil
        noteTemplate = usesBuiltInTemplate
            ? IdeaTemplateRenderer.defaultTemplate
            : storedTemplate!
        morningHour = defaults.object(forKey: Keys.morningHour) as? Int ?? 8
        morningMinute = defaults.object(forKey: Keys.morningMinute) as? Int ?? 30
        whisperModel = defaults.string(forKey: Keys.whisperModel) ?? "large-v3-v20240930_626MB"
        voiceCleanupMode = VoiceCleanupMode(
            rawValue: defaults.string(forKey: Keys.voiceCleanupMode) ?? ""
        ) ?? .light
        voiceActivationMode = VoiceActivationMode(
            rawValue: defaults.string(forKey: Keys.voiceActivationMode) ?? ""
        ) ?? .hold
        directVoiceInsertion = defaults.object(forKey: Keys.directVoiceInsertion) as? Bool ?? true
        isWhisperModelInstalled = defaults.bool(forKey: Keys.isWhisperModelInstalled)
        whisperModelPath = defaults.string(forKey: Keys.whisperModelPath) ?? ""
        voiceDictationShortcut = VoiceDictationShortcut(
            rawValue: defaults.string(forKey: Keys.voiceDictationShortcut) ?? ""
        ) ?? .controlShiftSpace
        researchDepth = ResearchDepth(
            rawValue: defaults.string(forKey: Keys.researchDepth) ?? ""
        ) ?? .quick
        researchDictationShortcut = ResearchDictationShortcut(
            rawValue: defaults.string(forKey: Keys.researchDictationShortcut) ?? ""
        ) ?? .controlShiftR
        translationDictationShortcut = TranslationDictationShortcut(
            rawValue: defaults.string(forKey: Keys.translationDictationShortcut) ?? ""
        ) ?? .controlShiftT
        voiceEditShortcut = VoiceEditShortcut(
            rawValue: defaults.string(forKey: Keys.voiceEditShortcut) ?? ""
        ) ?? .controlShiftE
        translationTarget = TranslationTarget(
            rawValue: defaults.string(forKey: Keys.translationTarget) ?? ""
        ) ?? .english
        voiceHistoryRetention = VoiceHistoryRetention(
            rawValue: defaults.string(forKey: Keys.voiceHistoryRetention) ?? ""
        ) ?? .month
        appAwareDictation = defaults.object(forKey: Keys.appAwareDictation) as? Bool ?? true
        interactionSounds = defaults.object(forKey: Keys.interactionSounds) as? Bool ?? true
        customWritingStyle = defaults.string(forKey: Keys.customWritingStyle) ?? ""
        microphoneDeviceID = UInt32(defaults.object(forKey: Keys.microphoneDeviceID) as? Int ?? 0)

        if storedInstructions == Self.legacyAIInstructions {
            defaults.set(customAIInstructions, forKey: Keys.customInstructions)
        }
        if usesBuiltInTemplate, storedTemplate != nil {
            defaults.set(noteTemplate, forKey: Keys.noteTemplate)
        }
    }

    func restoreDefaultTemplate() {
        noteTemplate = IdeaTemplateRenderer.defaultTemplate
    }

    private enum Keys {
        static let generationModel = "DailyDesk.generationModel"
        static let embeddingModel = "DailyDesk.embeddingModel"
        static let customInstructions = "DailyDesk.customAIInstructions"
        static let noteTemplate = "DailyDesk.noteTemplate"
        static let morningHour = "DailyDesk.morningHour"
        static let morningMinute = "DailyDesk.morningMinute"
        static let whisperModel = "DailyDesk.whisperModel"
        static let voiceCleanupMode = "DailyDesk.voiceCleanupMode"
        static let voiceActivationMode = "DailyDesk.voiceActivationMode"
        static let directVoiceInsertion = "DailyDesk.directVoiceInsertion"
        static let isWhisperModelInstalled = "DailyDesk.isWhisperModelInstalled"
        static let whisperModelPath = "DailyDesk.whisperModelPath"
        static let voiceDictationShortcut = "DailyDesk.voiceDictationShortcut"
        static let researchDepth = "DailyDesk.researchDepth"
        static let researchDictationShortcut = "DailyDesk.researchDictationShortcut"
        static let translationDictationShortcut = "DailyDesk.translationDictationShortcut"
        static let voiceEditShortcut = "DailyDesk.voiceEditShortcut"
        static let translationTarget = "DailyDesk.translationTarget"
        static let voiceHistoryRetention = "DailyDesk.voiceHistoryRetention"
        static let appAwareDictation = "DailyDesk.appAwareDictation"
        static let interactionSounds = "DailyDesk.interactionSounds"
        static let customWritingStyle = "DailyDesk.customWritingStyle"
        static let microphoneDeviceID = "DailyDesk.microphoneDeviceID"
    }
}
