import Foundation
import UserNotifications

@MainActor
final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var lastError: String?

    private let center = UNUserNotificationCenter.current()

    override private init() {
        super.init()
        center.delegate = self
        Task { await refreshStatus() }
    }

    func requestAuthorization() async {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshStatus()
            if authorizationStatus == .authorized || authorizationStatus == .provisional {
                await scheduleMorningReminder()
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refreshStatus() async {
        authorizationStatus = await center.notificationSettings().authorizationStatus
    }

    func scheduleMorningReminder() async {
        center.removePendingNotificationRequests(withIdentifiers: ["daily-desk.morning"])
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else { return }
        let settings = DailyDeskSettings.shared
        let content = UNMutableNotificationContent()
        content.title = "Plan a calm day"
        content.body = "Choose the few outcomes that would make today count."
        content.sound = .default
        content.categoryIdentifier = "DAILY_DESK_MORNING"
        var components = DateComponents()
        components.hour = settings.morningHour
        components.minute = settings.morningMinute
        let request = UNNotificationRequest(
            identifier: "daily-desk.morning",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )
        do {
            try await center.add(request)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func sendFocusFinished() {
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else { return }
        let content = UNMutableNotificationContent()
        content.title = "Focus session complete"
        content.body = "Take a breath, mark your progress, and choose what comes next."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "daily-desk.focus.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    func sendCaptureSaved(preview: String) {
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else { return }
        let content = UNMutableNotificationContent()
        content.title = "Saved to Nelyr"
        content.body = String(preview.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))
        content.sound = nil
        let request = UNNotificationRequest(
            identifier: "daily-desk.capture.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    func sendResearchFinished(query: String) {
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else { return }
        let content = UNMutableNotificationContent()
        content.title = "Grok research is ready"
        content.body = String(query.trimmingCharacters(in: .whitespacesAndNewlines).prefix(140))
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "daily-desk.research.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
