import Foundation
import UserNotifications

/// Thin wrapper around UNUserNotificationCenter for the menu-bar app.
final class NotificationManager {
    static let shared = NotificationManager()

    private var requestedAuthorization = false

    private init() {}

    /// Posts a quick notification. Requests authorization on first call.
    func notify(title: String, body: String) {
        ensureAuthorization { granted in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = nil  // sound is handled separately by the sound-feedback toggle
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil  // deliver immediately
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    private func ensureAuthorization(_ completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                completion(true)
            case .notDetermined:
                center.requestAuthorization(options: [.alert]) { granted, _ in
                    completion(granted)
                }
            default:
                completion(false)
            }
        }
    }
}
