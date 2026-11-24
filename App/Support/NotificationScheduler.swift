import Foundation
import UserNotifications

enum ReminderKeys {
    static let enabled = "reminder.enabled"
    static let hour = "reminder.hour"
    static let minute = "reminder.minute"
}

/// Die Teile von `UNUserNotificationCenter`, die der Scheduler braucht – als Protokoll,
/// damit Tests ein Fake-Center einsetzen können (Issue #180).
protocol NotificationCenterScheduling {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest)
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

extension UNUserNotificationCenter: NotificationCenterScheduling {
    func add(_ request: UNNotificationRequest) {
        add(request, withCompletionHandler: nil)
    }
}

/// Plant die tägliche Lern-Erinnerung als lokale Notification.
/// Lokale Notifications brauchen nur Runtime-Autorisierung – keine Entitlements.
enum NotificationScheduler {
    static let requestID = "daily.reminder"
    /// Austauschbar für Tests; im Betrieb das System-Center.
    static var center: NotificationCenterScheduling = UNUserNotificationCenter.current()

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

    /// Plant die Erinnerung neu, falls sie aktiviert ist – z.B. nach einem
    /// Sprachwechsel, damit Titel/Body in der neuen Sprache erscheinen.
    /// Nutzt dieselben Defaults (19:00) wie die Einstellungs-`@AppStorage`.
    static func rescheduleIfEnabled(defaults d: UserDefaults = AppGroup.defaults) {
        guard d.bool(forKey: ReminderKeys.enabled) else { return }
        let hour = d.object(forKey: ReminderKeys.hour) as? Int ?? 19
        let minute = d.object(forKey: ReminderKeys.minute) as? Int ?? 0
        schedule(hour: hour, minute: minute)
    }
}
