@testable import DailyHangul
import UserNotifications
import XCTest

/// Prüft die Planung der täglichen Erinnerung (Issue #180) gegen ein Fake-Center:
/// richtiger Kalender-Auslöser, Ersetzen statt Duplizieren, Abbrechen und
/// Neuplanung nur bei aktivierter Erinnerung.
final class NotificationSchedulerTests: XCTestCase {

    private var fake: FakeNotificationCenter!
    private var defaults: UserDefaults!
    private let suiteName = "NotificationSchedulerTests"

    override func setUp() {
        super.setUp()
        fake = FakeNotificationCenter()
        NotificationScheduler.center = fake
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        NotificationScheduler.center = UNUserNotificationCenter.current()
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        fake = nil
        super.tearDown()
    }

    // MARK: - schedule

    func testScheduleAddsOneRepeatingCalendarRequest() throws {
        NotificationScheduler.schedule(hour: 8, minute: 30)

        XCTAssertEqual(fake.pending.count, 1)
        let request = try XCTUnwrap(fake.pending.first)
        XCTAssertEqual(request.identifier, NotificationScheduler.requestID)
        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
        XCTAssertTrue(trigger.repeats)
        XCTAssertEqual(trigger.dateComponents.hour, 8)
        XCTAssertEqual(trigger.dateComponents.minute, 30)
        XCTAssertFalse(request.content.title.isEmpty)
        XCTAssertFalse(request.content.body.isEmpty)
    }

    func testRescheduleReplacesInsteadOfDuplicating() throws {
        NotificationScheduler.schedule(hour: 8, minute: 30)
        NotificationScheduler.schedule(hour: 21, minute: 5)

        XCTAssertEqual(fake.pending.count, 1)
        let trigger = try XCTUnwrap(fake.pending.first?.trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(trigger.dateComponents.hour, 21)
        XCTAssertEqual(trigger.dateComponents.minute, 5)
    }

    func testCancelRemovesRequest() {
        NotificationScheduler.schedule(hour: 8, minute: 30)
        NotificationScheduler.cancel()

        XCTAssertTrue(fake.pending.isEmpty)
        XCTAssertEqual(fake.removedIdentifiers.last, [NotificationScheduler.requestID])
    }

    // MARK: - rescheduleIfEnabled

    func testRescheduleIfEnabledDoesNothingWhenDisabled() {
        defaults.set(false, forKey: ReminderKeys.enabled)
        defaults.set(7, forKey: ReminderKeys.hour)

        NotificationScheduler.rescheduleIfEnabled(defaults: defaults)

        XCTAssertTrue(fake.pending.isEmpty)
        XCTAssertTrue(fake.removedIdentifiers.isEmpty)
    }

    func testRescheduleIfEnabledUsesStoredTime() throws {
        defaults.set(true, forKey: ReminderKeys.enabled)
        defaults.set(7, forKey: ReminderKeys.hour)
        defaults.set(45, forKey: ReminderKeys.minute)

        NotificationScheduler.rescheduleIfEnabled(defaults: defaults)

        let trigger = try XCTUnwrap(fake.pending.first?.trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(fake.pending.count, 1)
        XCTAssertEqual(trigger.dateComponents.hour, 7)
        XCTAssertEqual(trigger.dateComponents.minute, 45)
    }

    func testRescheduleIfEnabledFallsBackToDefaultTime() throws {
        defaults.set(true, forKey: ReminderKeys.enabled)

        NotificationScheduler.rescheduleIfEnabled(defaults: defaults)

        let trigger = try XCTUnwrap(fake.pending.first?.trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(trigger.dateComponents.hour, 19)
        XCTAssertEqual(trigger.dateComponents.minute, 0)
    }

    // MARK: - requestAuthorization

    func testRequestAuthorizationReturnsGrant() async {
        fake.authorizationResult = .success(true)
        let granted = await NotificationScheduler.requestAuthorization()
        XCTAssertTrue(granted)
        XCTAssertEqual(fake.requestedOptions, [.alert, .sound, .badge])
    }

    func testRequestAuthorizationReturnsDenial() async {
        fake.authorizationResult = .success(false)
        let granted = await NotificationScheduler.requestAuthorization()
        XCTAssertFalse(granted)
    }

    func testRequestAuthorizationTreatsErrorAsDenial() async {
        fake.authorizationResult = .failure(FakeError.denied)
        let granted = await NotificationScheduler.requestAuthorization()
        XCTAssertFalse(granted)
    }
}

private enum FakeError: Error {
    case denied
}

/// Bildet das Verhalten von `UNUserNotificationCenter` für ausstehende Requests nach:
/// gleiche Kennung ersetzt, Entfernen per Kennung löscht.
private final class FakeNotificationCenter: NotificationCenterScheduling {
    private(set) var pending: [UNNotificationRequest] = []
    private(set) var removedIdentifiers: [[String]] = []
    private(set) var requestedOptions: UNAuthorizationOptions?
    var authorizationResult: Result<Bool, Error> = .success(true)

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestedOptions = options
        return try authorizationResult.get()
    }

    func add(_ request: UNNotificationRequest) {
        pending.removeAll { $0.identifier == request.identifier }
        pending.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(identifiers)
        pending.removeAll { identifiers.contains($0.identifier) }
    }
}
