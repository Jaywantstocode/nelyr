import AppKit
import SwiftUI

@main
struct NelyrApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = DailyDeskModel.shared
    @StateObject private var timer = FocusTimer.shared
    @StateObject private var pipeline = IdeaPipeline.shared
    @StateObject private var vault = VaultManager.shared
    @StateObject private var settings = DailyDeskSettings.shared
    @StateObject private var notifications = NotificationService.shared

    var body: some Scene {
        Window("Nelyr", id: "main") {
            DashboardView()
                .environmentObject(model)
                .environmentObject(timer)
                .environmentObject(pipeline)
                .environmentObject(vault)
                .frame(minWidth: 760, minHeight: 560)
        }
        .defaultSize(width: 920, height: 720)
        .windowStyle(.hiddenTitleBar)

        Window("Morning Plan", id: "morning") {
            MorningPlanView()
                .environmentObject(model)
                .environmentObject(timer)
        }
        .defaultSize(width: 680, height: 520)
        .windowStyle(.hiddenTitleBar)

        Window("Desk Tile", id: "tile") {
            DeskTileView()
                .environmentObject(model)
                .environmentObject(timer)
                .frame(width: 360)
        }
        .defaultSize(width: 360, height: 430)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add Priority") {
                    NotificationCenter.default.post(name: .focusPriorityField, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandMenu("Focus") {
                Button(timer.isRunning ? "Pause Timer" : "Start Timer") {
                    timer.toggle()
                }
                .keyboardShortcut(.space, modifiers: [.command, .shift])

                Button("Reset Timer") { timer.reset() }
            }
        }

        MenuBarExtra {
            MenuBarView()
                .environmentObject(model)
                .environmentObject(timer)
                .environmentObject(pipeline)
                .environmentObject(vault)
        } label: {
            Image(systemName: model.openPriorityCount == 0 && !model.priorities.isEmpty
                  ? "checkmark.circle.fill"
                  : "waveform.path.ecg")
                .symbolRenderingMode(.hierarchical)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(pipeline)
                .environmentObject(vault)
                .environmentObject(notifications)
        }
    }
}

extension Notification.Name {
    static let focusPriorityField = Notification.Name("DailyDesk.focusPriorityField")
    static let openMorningPlan = Notification.Name("DailyDesk.openMorningPlan")
    static let voiceShortcutChanged = Notification.Name("DailyDesk.voiceShortcutChanged")
    static let translationShortcutChanged = Notification.Name("DailyDesk.translationShortcutChanged")
    static let voiceEditShortcutChanged = Notification.Name("DailyDesk.voiceEditShortcutChanged")
    static let researchShortcutChanged = Notification.Name("DailyDesk.researchShortcutChanged")
}
