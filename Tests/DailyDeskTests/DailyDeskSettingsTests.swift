import Foundation
import XCTest
@testable import Nelyr

@MainActor
final class DailyDeskSettingsTests: XCTestCase {
    func testLegacyDefaultTemplateMigratesToLifeCaptureTemplate() {
        let suite = "DailyDeskSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(IdeaTemplateRenderer.legacyDefaultTemplate, forKey: "DailyDesk.noteTemplate")

        let settings = DailyDeskSettings(defaults: defaults)

        XCTAssertEqual(settings.noteTemplate, IdeaTemplateRenderer.defaultTemplate)
        XCTAssertTrue(settings.noteTemplate.contains("type: {{type}}"))
        XCTAssertTrue(settings.noteTemplate.contains("## Why it matters"))
    }

    func testPreviousBuiltInTemplateMigratesToScreenshotAwareTemplate() {
        let suite = "DailyDeskSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(IdeaTemplateRenderer.previousDefaultTemplate, forKey: "DailyDesk.noteTemplate")

        let settings = DailyDeskSettings(defaults: defaults)

        XCTAssertEqual(settings.noteTemplate, IdeaTemplateRenderer.defaultTemplate)
        XCTAssertTrue(settings.noteTemplate.contains("capture_kind: {{capture_kind}}"))
    }

    func testCustomizedTemplateIsPreserved() {
        let suite = "DailyDeskSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let custom = IdeaTemplateRenderer.legacyDefaultTemplate + "\nPersonal footer"
        defaults.set(custom, forKey: "DailyDesk.noteTemplate")

        let settings = DailyDeskSettings(defaults: defaults)

        XCTAssertEqual(settings.noteTemplate, custom)
    }

    func testVoiceDefaultsFavorPrivateLightCleanup() {
        let suite = "DailyDeskSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = DailyDeskSettings(defaults: defaults)

        XCTAssertEqual(settings.whisperModel, "large-v3-v20240930_626MB")
        XCTAssertEqual(settings.voiceCleanupMode, .light)
        XCTAssertTrue(settings.directVoiceInsertion)
        XCTAssertFalse(settings.isWhisperModelInstalled)
        XCTAssertEqual(settings.voiceDictationShortcut, .controlShiftSpace)
        XCTAssertEqual(settings.voiceActivationMode, .hold)
        XCTAssertEqual(settings.researchDepth, .quick)
        XCTAssertEqual(settings.researchDictationShortcut, .controlShiftR)
        XCTAssertEqual(settings.translationDictationShortcut, .controlShiftT)
        XCTAssertEqual(settings.voiceEditShortcut, .controlShiftE)
        XCTAssertEqual(settings.translationTarget, .english)
        XCTAssertEqual(settings.voiceHistoryRetention, .month)
        XCTAssertTrue(settings.appAwareDictation)
        XCTAssertTrue(settings.interactionSounds)
    }

    func testVoiceActivationModePersists() {
        let suite = "DailyDeskSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = DailyDeskSettings(defaults: defaults)
        settings.voiceActivationMode = .toggle

        XCTAssertEqual(DailyDeskSettings(defaults: defaults).voiceActivationMode, .toggle)
    }

    func testResearchPreferencesPersist() {
        let suite = "DailyDeskSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = DailyDeskSettings(defaults: defaults)
        settings.researchDepth = .deep
        settings.researchDictationShortcut = .controlOptionR
        let reloaded = DailyDeskSettings(defaults: defaults)

        XCTAssertEqual(reloaded.researchDepth, .deep)
        XCTAssertEqual(reloaded.researchDictationShortcut, .controlOptionR)
    }
}
