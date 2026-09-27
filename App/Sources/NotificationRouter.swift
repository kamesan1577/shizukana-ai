import Foundation
import Observation
import UserNotifications

@MainActor @Observable
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    var selectedID: UUID?

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        guard let value = response.notification.request.content.userInfo["utteranceID"] as? String,
              let id = UUID(uuidString: value) else { return }
        await MainActor.run { self.selectedID = id }
    }
}
