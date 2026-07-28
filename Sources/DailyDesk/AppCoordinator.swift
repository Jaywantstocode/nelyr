import AppKit
import Carbon.HIToolbox
import KeyboardShortcuts
import OSLog
import SwiftUI

private extension KeyboardShortcuts.Name {
    static let captureThought = Self("dailyDeskCaptureThought")
    static let dictateAnywhere = Self("dailyDeskDictateAnywhere")
    static let voiceResearch = Self("dailyDeskVoiceResearch")
    static let translateDictation = Self("dailyDeskTranslateDictation")
    static let voiceEdit = Self("dailyDeskVoiceEdit")
}

private extension VoiceDictationShortcut {
    var keyboardShortcut: KeyboardShortcuts.Shortcut {
        .init(carbonKeyCode: Int(keyCode), carbonModifiers: Int(carbonModifiers))
    }
}

private extension ResearchDictationShortcut {
    var keyboardShortcut: KeyboardShortcuts.Shortcut {
        .init(carbonKeyCode: Int(keyCode), carbonModifiers: Int(carbonModifiers))
    }
}

private extension TranslationDictationShortcut {
    var keyboardShortcut: KeyboardShortcuts.Shortcut {
        .init(carbonKeyCode: Int(keyCode), carbonModifiers: Int(carbonModifiers))
    }
}

private extension VoiceEditShortcut {
    var keyboardShortcut: KeyboardShortcuts.Shortcut {
        .init(carbonKeyCode: Int(keyCode), carbonModifiers: Int(carbonModifiers))
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var localEscapeMonitor: Any?
    private var globalEscapeMonitor: Any?
    private var widgetSyncTimer: Timer?
    private let logger = Logger(subsystem: "ooo.cavin.dailydesk", category: "lifecycle")

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.notice("Nelyr launched")
        _ = NotificationService.shared
        NSApp.servicesProvider = SelectionCaptureService.shared
        NSUpdateDynamicServices()
        configureGlobalShortcuts()
        CapsLockCaffeinateController.shared.synchronize()
        WidgetSnapshotWriter.update()
        widgetSyncTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                DailyDeskModel.shared.syncPrioritiesFromWidget()
                CapsLockCaffeinateController.shared.synchronize()
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(voiceShortcutChanged),
            name: .voiceShortcutChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(translationShortcutChanged),
            name: .translationShortcutChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(voiceEditShortcutChanged),
            name: .voiceEditShortcutChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(researchShortcutChanged),
            name: .researchShortcutChanged,
            object: nil
        )

        let workspaceNotifications = NSWorkspace.shared.notificationCenter
        workspaceNotifications.addObserver(
            self,
            selector: #selector(systemDidResume),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        workspaceNotifications.addObserver(
            self,
            selector: #selector(systemDidResume),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
        workspaceNotifications.addObserver(
            self,
            selector: #selector(systemDidResume),
            name: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil
        )

        localEscapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape), VoiceDictationController.shared.isRecording {
                if VoiceDictationController.shared.activeDestination == .research {
                    ResearchController.shared.cancelVoiceCapture()
                } else {
                    VoiceDictationController.shared.cancel()
                }
                return nil
            }
            return event
        }
        globalEscapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            guard event.keyCode == UInt16(kVK_Escape) else { return }
            Task { @MainActor in
                if VoiceDictationController.shared.activeDestination == .research {
                    ResearchController.shared.cancelVoiceCapture()
                } else {
                    VoiceDictationController.shared.cancel()
                }
            }
        }

        Task { @MainActor in
            await IdeaPipeline.shared.checkOllama()
            await VoiceDictationController.shared.prepareInstalledModel()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        logger.notice("Nelyr received applicationWillTerminate")
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        if let localEscapeMonitor { NSEvent.removeMonitor(localEscapeMonitor) }
        if let globalEscapeMonitor { NSEvent.removeMonitor(globalEscapeMonitor) }
        widgetSyncTimer?.invalidate()
        CapsLockCaffeinateController.shared.stop()
        KeyboardShortcuts.removeAllHandlers()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        DailyDeskModel.shared.syncPrioritiesFromWidget()
        CapsLockCaffeinateController.shared.synchronize()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    @objc private func voiceShortcutChanged() {
        KeyboardShortcuts.setShortcut(
            DailyDeskSettings.shared.voiceDictationShortcut.keyboardShortcut,
            for: .dictateAnywhere
        )
        reportDictationRegistrationState()
        WidgetSnapshotWriter.update()
    }

    @objc private func researchShortcutChanged() {
        KeyboardShortcuts.setShortcut(
            DailyDeskSettings.shared.researchDictationShortcut.keyboardShortcut,
            for: .voiceResearch
        )
        WidgetSnapshotWriter.update()
    }

    @objc private func translationShortcutChanged() {
        KeyboardShortcuts.setShortcut(
            DailyDeskSettings.shared.translationDictationShortcut.keyboardShortcut,
            for: .translateDictation
        )
        WidgetSnapshotWriter.update()
    }

    @objc private func voiceEditShortcutChanged() {
        KeyboardShortcuts.setShortcut(
            DailyDeskSettings.shared.voiceEditShortcut.keyboardShortcut,
            for: .voiceEdit
        )
        WidgetSnapshotWriter.update()
    }

    @objc private func systemDidResume() {
        logger.notice("macOS session resumed; clearing stale hold state")
        VoiceDictationController.shared.cancelStaleShortcutState()
        CapsLockCaffeinateController.shared.synchronize()
    }

    private func configureGlobalShortcuts() {
        KeyboardShortcuts.removeAllHandlers()
        synchronizeShortcutBindings()

        KeyboardShortcuts.onKeyDown(for: .captureThought) {
            CapturePanelController.shared.show()
        }
        KeyboardShortcuts.onKeyDown(for: .dictateAnywhere) {
            VoiceDictationController.shared.systemwideKeyPressed()
        }
        KeyboardShortcuts.onKeyUp(for: .dictateAnywhere) {
            VoiceDictationController.shared.systemwideKeyReleased()
        }
        KeyboardShortcuts.onKeyDown(for: .voiceResearch) {
            ResearchController.shared.systemwideKeyPressed()
        }
        KeyboardShortcuts.onKeyUp(for: .voiceResearch) {
            ResearchController.shared.systemwideKeyReleased()
        }
        KeyboardShortcuts.onKeyDown(for: .translateDictation) {
            VoiceDictationController.shared.translationKeyPressed()
        }
        KeyboardShortcuts.onKeyDown(for: .voiceEdit) {
            VoiceDictationController.shared.voiceEditKeyPressed()
        }

        reportDictationRegistrationState()
        logger.notice("Global shortcuts configured with shared Carbon event routing")
    }

    private func synchronizeShortcutBindings() {
        KeyboardShortcuts.setShortcut(
            .init(.space, modifiers: [.control, .option]),
            for: .captureThought
        )
        KeyboardShortcuts.setShortcut(
            DailyDeskSettings.shared.voiceDictationShortcut.keyboardShortcut,
            for: .dictateAnywhere
        )
        KeyboardShortcuts.setShortcut(
            DailyDeskSettings.shared.researchDictationShortcut.keyboardShortcut,
            for: .voiceResearch
        )
        KeyboardShortcuts.setShortcut(
            DailyDeskSettings.shared.translationDictationShortcut.keyboardShortcut,
            for: .translateDictation
        )
        KeyboardShortcuts.setShortcut(
            DailyDeskSettings.shared.voiceEditShortcut.keyboardShortcut,
            for: .voiceEdit
        )
    }

    private func reportDictationRegistrationState() {
        if KeyboardShortcuts.isEnabled(for: .dictateAnywhere) {
            VoiceDictationController.shared.reportHotKeyRegistrationSuccess()
        } else {
            logger.error("Dictation shortcut registration failed")
            VoiceDictationController.shared.reportHotKeyRegistrationFailure()
        }
    }
}

@MainActor
final class CapturePanelController {
    static let shared = CapturePanelController()
    private var panel: NSPanel?

    func show(prefilledText: String = "") {
        if panel == nil { panel = makePanel(initialText: prefilledText) }
        else { panel?.contentView = NSHostingView(rootView: QuickCaptureView(initialText: prefilledText)) }
        setScreenshotExpanded(false, animated: false)
        NSApplication.shared.activate(ignoringOtherApps: true)
        panel?.center()
        panel?.makeKeyAndOrderFront(nil)
    }

    func close() {
        setScreenshotExpanded(false, animated: false)
        panel?.orderOut(nil)
    }

    func setScreenshotExpanded(_ expanded: Bool, animated: Bool = true) {
        guard let panel else { return }
        let size = NSSize(width: expanded ? 650 : 580, height: expanded ? 560 : 350)
        guard panel.frame.size != size else { return }
        let center = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        let frame = NSRect(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        panel.setFrame(frame, display: true, animate: animated && panel.isVisible)
    }

    private func makePanel(initialText: String) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 350),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: QuickCaptureView(initialText: initialText))
        return panel
    }
}
