import Foundation
import UserNotifications

enum Notifier {
    /// UserNotifications exige um bundle; fora do .app (swift run) as notificações são ignoradas.
    private static var available: Bool { Bundle.main.bundleIdentifier != nil }

    static func requestAuthorization() {
        guard available else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func send(_ body: String) {
        guard available,
              UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true else { return }
        let content = UNMutableNotificationContent()
        content.title = "GH Switcher"
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
