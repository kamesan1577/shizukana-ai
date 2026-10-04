import Foundation
import UserNotifications
import QuietCore

protocol NotificationScheduling: Sendable {
    func schedule(_ utterance: Utterance, at date: Date, identifier: String) async
    func pendingIDs() async -> Set<String>
    func removePending(_ identifiers: [String]) async
    func removeAll() async
}

struct LocalNotificationScheduler: NotificationScheduling {
    func schedule(_ utterance: Utterance, at date: Date, identifier: String) async {
        let content = UNMutableNotificationContent()
        content.body = utterance.text
        content.userInfo = ["utteranceID": utterance.id.uuidString]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }
    func pendingIDs() async -> Set<String> {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return Set(requests.map(\.identifier))
    }
    func removePending(_ identifiers: [String]) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    func removeAll() async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
}
