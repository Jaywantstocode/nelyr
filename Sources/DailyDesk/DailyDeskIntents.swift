import AppIntents
import Foundation

struct CaptureIdeaIntent: AppIntent {
    static let title: LocalizedStringResource = "Capture Thought"
    static let description = IntentDescription("Save a life thought to Nelyr and categorize it locally in your Obsidian vault.")
    static let openAppWhenRun = false

    @Parameter(title: "Thought")
    var idea: String

    static var parameterSummary: some ParameterSummary {
        Summary("Capture \(\.$idea)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let saved = await MainActor.run { () -> Bool in
            guard VaultManager.shared.vaultURL != nil else { return false }
            DailyDeskModel.shared.captureIdea(idea)
            return true
        }
        return .result(dialog: saved
            ? "Thought saved. Local categorization will continue in the background."
            : "Choose an Obsidian vault in Nelyr first.")
    }
}

struct StartFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Focus"
    static let description = IntentDescription("Start Nelyr's 25-minute focus timer.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run { FocusTimer.shared.start() }
        return .result(dialog: "Focus timer started for 25 minutes.")
    }
}

struct OpenMorningPlanIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Morning Plan"
    static let description = IntentDescription("Open Nelyr to choose today's priorities.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: .openMorningPlan, object: nil)
        }
        return .result()
    }
}
