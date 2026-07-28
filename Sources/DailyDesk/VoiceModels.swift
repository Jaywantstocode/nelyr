import Carbon.HIToolbox
import Foundation

enum VoiceActivationMode: String, CaseIterable, Identifiable, Sendable {
    case hold
    case toggle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hold: "Hold to talk"
        case .toggle: "Press to start / stop"
        }
    }

    var detail: String {
        switch self {
        case .hold: "Hold the shortcut while speaking, then release to transcribe."
        case .toggle: "Press once to start recording and press again to transcribe."
        }
    }
}

enum VoiceDictationShortcut: String, CaseIterable, Identifiable, Sendable {
    case controlShiftSpace
    case controlOptionV
    case commandShiftD

    var id: String { rawValue }

    var title: String {
        switch self {
        case .controlShiftSpace: "Control–Shift–Space"
        case .controlOptionV: "Control–Option–V"
        case .commandShiftD: "Command–Shift–D"
        }
    }

    var symbols: String {
        switch self {
        case .controlShiftSpace: "⌃⇧Space"
        case .controlOptionV: "⌃⌥V"
        case .commandShiftD: "⌘⇧D"
        }
    }

    var keyCode: UInt32 {
        switch self {
        case .controlShiftSpace: UInt32(kVK_Space)
        case .controlOptionV: UInt32(kVK_ANSI_V)
        case .commandShiftD: UInt32(kVK_ANSI_D)
        }
    }

    var carbonModifiers: UInt32 {
        switch self {
        case .controlShiftSpace: UInt32(controlKey | shiftKey)
        case .controlOptionV: UInt32(controlKey | optionKey)
        case .commandShiftD: UInt32(cmdKey | shiftKey)
        }
    }
}

enum TranslationDictationShortcut: String, CaseIterable, Identifiable, Sendable {
    case controlShiftT
    case controlOptionT
    case commandShiftT

    var id: String { rawValue }
    var title: String {
        switch self {
        case .controlShiftT: "Control–Shift–T"
        case .controlOptionT: "Control–Option–T"
        case .commandShiftT: "Command–Shift–T"
        }
    }
    var symbols: String {
        switch self {
        case .controlShiftT: "⌃⇧T"
        case .controlOptionT: "⌃⌥T"
        case .commandShiftT: "⌘⇧T"
        }
    }
    var keyCode: UInt32 { UInt32(kVK_ANSI_T) }
    var carbonModifiers: UInt32 {
        switch self {
        case .controlShiftT: UInt32(controlKey | shiftKey)
        case .controlOptionT: UInt32(controlKey | optionKey)
        case .commandShiftT: UInt32(cmdKey | shiftKey)
        }
    }
}

enum VoiceEditShortcut: String, CaseIterable, Identifiable, Sendable {
    case controlShiftE
    case controlOptionE
    case commandShiftE

    var id: String { rawValue }
    var title: String {
        switch self {
        case .controlShiftE: "Control–Shift–E"
        case .controlOptionE: "Control–Option–E"
        case .commandShiftE: "Command–Shift–E"
        }
    }
    var symbols: String {
        switch self {
        case .controlShiftE: "⌃⇧E"
        case .controlOptionE: "⌃⌥E"
        case .commandShiftE: "⌘⇧E"
        }
    }
    var keyCode: UInt32 { UInt32(kVK_ANSI_E) }
    var carbonModifiers: UInt32 {
        switch self {
        case .controlShiftE: UInt32(controlKey | shiftKey)
        case .controlOptionE: UInt32(controlKey | optionKey)
        case .commandShiftE: UInt32(cmdKey | shiftKey)
        }
    }
}

enum TranslationTarget: String, CaseIterable, Codable, Identifiable, Sendable {
    case english, japanese, spanish, french, german, korean, chinese, portuguese, italian

    var id: String { rawValue }
    var title: String {
        switch self {
        case .english: "English"
        case .japanese: "Japanese"
        case .spanish: "Spanish"
        case .french: "French"
        case .german: "German"
        case .korean: "Korean"
        case .chinese: "Chinese (Simplified)"
        case .portuguese: "Portuguese"
        case .italian: "Italian"
        }
    }
}

enum VoiceHistoryRetention: String, CaseIterable, Codable, Identifiable, Sendable {
    case never, day, week, month, forever

    var id: String { rawValue }
    var title: String {
        switch self {
        case .never: "Never"
        case .day: "24 hours"
        case .week: "1 week"
        case .month: "1 month"
        case .forever: "Forever"
        }
    }

    var interval: TimeInterval? {
        switch self {
        case .never: 0
        case .day: 86_400
        case .week: 604_800
        case .month: 2_592_000
        case .forever: nil
        }
    }
}

struct DictationAppContext: Codable, Equatable, Sendable {
    let appName: String?
    let bundleIdentifier: String?

    var writingContext: String {
        let value = "\(appName ?? "") \(bundleIdentifier ?? "")".lowercased()
        if ["mail", "outlook", "gmail"].contains(where: value.contains) { return "email" }
        if ["slack", "messages", "discord", "teams", "whatsapp", "line"].contains(where: value.contains) { return "chat" }
        if ["xcode", "cursor", "visual studio code", "terminal", "iterm"].contains(where: value.contains) { return "technical" }
        if ["notes", "notion", "obsidian", "pages", "word", "docs"].contains(where: value.contains) { return "document" }
        return "general"
    }
}

enum ResearchDictationShortcut: String, CaseIterable, Identifiable, Sendable {
    case controlShiftR
    case controlOptionR
    case commandShiftR

    var id: String { rawValue }

    var title: String {
        switch self {
        case .controlShiftR: "Control–Shift–R"
        case .controlOptionR: "Control–Option–R"
        case .commandShiftR: "Command–Shift–R"
        }
    }

    var symbols: String {
        switch self {
        case .controlShiftR: "⌃⇧R"
        case .controlOptionR: "⌃⌥R"
        case .commandShiftR: "⌘⇧R"
        }
    }

    var keyCode: UInt32 { UInt32(kVK_ANSI_R) }

    var carbonModifiers: UInt32 {
        switch self {
        case .controlShiftR: UInt32(controlKey | shiftKey)
        case .controlOptionR: UInt32(controlKey | optionKey)
        case .commandShiftR: UInt32(cmdKey | shiftKey)
        }
    }
}

enum VoiceCleanupMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case none
    case light
    case polished

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "Raw"
        case .light: "Light"
        case .polished: "Polished"
        }
    }

    var detail: String {
        switch self {
        case .none: "Insert the exact Whisper transcript."
        case .light: "Remove fillers and repetitions; preserve your wording."
        case .polished: "Improve clarity and structure while preserving meaning."
        }
    }
}

enum VoiceDictationState: Equatable, Sendable {
    case idle
    case needsModel
    case preparingModel(progress: Double?)
    case recording(startedAt: Date)
    case transcribing
    case cleaning
    case inserting
    case copied
    case completed
    case failed(String)

    var isBusy: Bool {
        switch self {
        case .preparingModel, .recording, .transcribing, .cleaning, .inserting: true
        default: false
        }
    }
}

enum VoiceDestination: Equatable, Sendable {
    case quickCapture
    case systemwide
    case research
    case translation
    case voiceEdit
}

struct VoiceTranscription: Equatable, Sendable {
    let text: String
    let detectedLanguage: String?
}

enum DictationLanguageGuard {
    static func accepts(
        cleaned: String,
        source: String,
        detectedLanguage: String?
    ) -> Bool {
        let sourceIsJapanese = detectedLanguage?.lowercased().hasPrefix("ja") == true
            || containsJapaneseScript(source)
        guard sourceIsJapanese else { return true }
        return containsJapaneseScript(cleaned)
    }

    private static func containsJapaneseScript(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3040...0x30FF, // Hiragana and Katakana
                 0x31F0...0x31FF, // Katakana phonetic extensions
                 0x4E00...0x9FFF: // CJK unified ideographs
                true
            default:
                false
            }
        }
    }
}

enum VoiceDictationError: LocalizedError, Equatable {
    case modelNotInstalled
    case microphoneDenied
    case alreadyRecording
    case recordingUnavailable(String)
    case emptyRecording
    case emptyTranscript
    case accessibilityUnavailable
    case noSelectedText

    var errorDescription: String? {
        switch self {
        case .modelNotInstalled: "Install the local Whisper model in Voice settings first."
        case .microphoneDenied: "Microphone access is required for local voice transcription."
        case .alreadyRecording: "Nelyr is already recording."
        case .recordingUnavailable(let reason): "Recording could not start: \(reason)"
        case .emptyRecording: "No audible speech was recorded."
        case .emptyTranscript: "Whisper did not detect any speech."
        case .accessibilityUnavailable: "Copied to the clipboard. Press Command–V to paste."
        case .noSelectedText: "Select some editable text before starting Voice Edit."
        }
    }
}
