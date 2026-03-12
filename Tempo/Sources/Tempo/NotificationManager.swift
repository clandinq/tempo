import UserNotifications
import AppKit

// MARK: - NotificationManager

/// Wraps UNUserNotificationCenter for Tempo's two reminder types:
///   - "break"  – fired after N minutes of continuous tracking
///   - "resume" – fired after M minutes of being stopped
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    private enum ID {
        static let breakReminder  = "tempo.break"
        static let resumeReminder = "tempo.resume"
    }

    private enum ActionID {
        static let startBreak = "tempo.action.startBreak"
        static let dismiss    = "tempo.action.dismiss"
    }

    private enum CategoryID {
        static let breakReminder = "tempo.category.break"
    }

    var onStartBreak: (() -> Void)?
    var onBreakDismissed: (() -> Void)?

    override init() {
        super.init()
        center.delegate = self

        let startAction = UNNotificationAction(
            identifier: ActionID.startBreak,
            title: "Start Break",
            options: .foreground
        )
        let dismissAction = UNNotificationAction(
            identifier: ActionID.dismiss,
            title: "Dismiss",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: CategoryID.breakReminder,
            actions: [startAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([category])
    }

    // MARK: Permission

    func requestPermission() {
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                print("Tempo notifications: permission error: \(error)")
            } else {
                print("Tempo notifications: permission granted = \(granted)")
            }
        }
    }

    // MARK: Break reminder

    func scheduleBreak(projectName: String, in seconds: TimeInterval) {
        cancelBreak()
        guard seconds > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Time for a break!"
        content.body  = "You've been working on \"\(projectName)\" for \(Int(seconds / 60)) minutes."
        content.sound = .default
        content.categoryIdentifier = CategoryID.breakReminder

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: ID.breakReminder, content: content, trigger: trigger)

        center.add(request) { error in
            if let error { print("Tempo: break notification error: \(error)") }
        }
    }

    func cancelBreak() {
        center.removePendingNotificationRequests(withIdentifiers: [ID.breakReminder])
    }

    func checkAuthorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async { completion(settings.authorizationStatus) }
        }
    }

    func scheduleTest() {
        let content = UNMutableNotificationContent()
        content.title = "Tempo notifications are working!"
        content.body  = "Break and resume reminders will appear like this."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request  = UNNotificationRequest(identifier: "tempo.test", content: content, trigger: trigger)

        center.add(request) { error in
            if let error { print("Tempo: test notification error: \(error)") }
        }
    }

    // MARK: Resume reminder

    func scheduleResume(in seconds: TimeInterval) {
        cancelResume()
        guard seconds > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Ready to get back to it?"
        content.body  = "You've been away for \(Int(seconds / 60)) minutes."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: ID.resumeReminder, content: content, trigger: trigger)

        center.add(request) { error in
            if let error { print("Tempo: resume notification error: \(error)") }
        }
    }

    func cancelResume() {
        center.removePendingNotificationRequests(withIdentifiers: [ID.resumeReminder])
    }

    // MARK: UNUserNotificationCenterDelegate

    /// Show banner even when the app is frontmost (menu is open).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        handler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler handler: @escaping () -> Void
    ) {
        switch response.actionIdentifier {
        case ActionID.startBreak:
            DispatchQueue.main.async { self.onStartBreak?() }
        case ActionID.dismiss, UNNotificationDismissActionIdentifier:
            DispatchQueue.main.async { self.onBreakDismissed?() }
        default:
            break
        }
        handler()
    }
}
