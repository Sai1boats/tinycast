import Foundation
import UserNotifications

@MainActor protocol TodoReminderScheduling {
    func authorize() async throws
    func synchronize(_ items: [LocalTodo]) async throws
}

enum TodoReminderError: LocalizedError {
    case denied, past, capacity

    var errorDescription: String? {
        switch self {
        case .denied: String(localized: "Allow Tinycast notifications in System Settings to receive reminders.")
        case .past: String(localized: "Choose a future reminder time.")
        case .capacity:
            String(localized: "Some reminders could not be scheduled. Reduce the number of active reminders and retry.")
        }
    }
}

final class TodoReminders: NSObject, UNUserNotificationCenterDelegate, TodoReminderScheduling {
    private let prefix = "local-todo."
    private var center: UNUserNotificationCenter { .current() }
    var openItem: ((UUID) -> Void)?

    func start() { center.delegate = self }

    func authorize() async throws {
        guard try await center.requestAuthorization(options: [.alert, .sound]) else { throw TodoReminderError.denied }
    }

    func synchronize(_ items: [LocalTodo]) async throws {
        let pending = await center.pendingNotificationRequests().filter { $0.identifier.hasPrefix(prefix) }
        let existing = Dictionary(uniqueKeysWithValues: pending.map { ($0.identifier, $0) })
        let now = Date()
        let upcoming = items.filter { !$0.isCompleted && ($0.reminder ?? .distantPast) > now }
        let wanted = Set(upcoming.map { prefix + $0.id.uuidString })
        center.removePendingNotificationRequests(withIdentifiers: existing.keys.filter { !wanted.contains($0) })
        guard !upcoming.isEmpty else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            throw TodoReminderError.denied
        }
        for item in upcoming {
            guard let date = item.reminder, date > Date() else { continue }
            let id = prefix + item.id.uuidString
            let title = item.project ?? String(localized: "Local Todos")
            if let old = existing[id], old.content.body == item.title, old.content.title == title,
                let trigger = old.trigger as? UNCalendarNotificationTrigger,
                let fire = trigger.nextTriggerDate(), abs(fire.timeIntervalSince(date)) < 1 { continue }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = item.title
            content.sound = .default
            content.userInfo = ["todo": item.id.uuidString]
            try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: Self.trigger(at: date)))
        }
        let scheduled = Set(await center.pendingNotificationRequests().map(\.identifier))
        let missing = upcoming.contains {
            ($0.reminder ?? .distantPast) > Date() && !scheduled.contains(prefix + $0.id.uuidString)
        }
        if missing {
            throw TodoReminderError.capacity
        }
    }

    static func trigger(at date: Date) -> UNCalendarNotificationTrigger {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let parts = calendar.dateComponents([.calendar, .timeZone, .year, .month, .day, .hour, .minute, .second], from: date)
        return UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions { [.banner, .list, .sound] }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        guard let raw = response.notification.request.content.userInfo["todo"] as? String,
            let id = UUID(uuidString: raw) else { return }
        await MainActor.run { openItem?(id) }
    }
}
