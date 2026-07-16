import Foundation
import UserNotifications

enum ReminderKeys {
    static let enabled = "reminder.enabled"
    static let hour = "reminder.hour"
    static let minute = "reminder.minute"
}

/// Plant die tägliche Lern-Erinnerung als lokale Notification.
/// Lokale Notifications brauchen nur Runtime-Autorisierung – keine Entitlements.
enum NotificationScheduler {
    private static let requestID = "daily.reminder"
    private static var center: UNUserNotificationCenter { .current() }

    /// Fragt die Berechtigung an. Liefert `true`, wenn erlaubt.
    static func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Plant die tägliche Erinnerung zur gegebenen Uhrzeit (ersetzt eine bestehende).
    /// Titel/Body werden über die aktuell gewählte App-Sprache lokalisiert.
    static func schedule(hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = L("notification.title")
        content.body = L("notification.body")
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        cancel()
        center.add(UNNotificationRequest(identifier: requestID, content: content, trigger: trigger))
    }

    static func cancel() {
        center.removePendingNotificationRequests(withIdentifiers: [requestID])
    }
}
