import Foundation
import UserNotifications

/// Carries a tapped recall notification to the screen that can navigate to it.
///
/// Nothing new travels here: the notification was posted locally by
/// `BackgroundRefresh`, and all it carries is a medication name this phone
/// already stored.
@MainActor
@Observable
final class NotificationRouter {
    static let shared = NotificationRouter()

    /// Which medication — and when there's only one, which recall — was tapped.
    struct Target: Equatable {
        let medicationName: String
        let recallNumber: String?
    }

    /// Set when a notification is tapped, cleared once it's been navigated to.
    /// A tap can arrive before the list screen exists (it's what launched the
    /// app), so this is read on appear as well as watched for changes.
    var pending: Target?

    /// Must be called before the app finishes launching, or a tap that cold
    /// launched the app is delivered with no delegate to receive it.
    nonisolated static func start() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    fileprivate func received(medication: String, recall: String?) {
        pending = Target(medicationName: medication, recallNumber: recall)
    }
}

/// Split out because `UNUserNotificationCenterDelegate` needs an NSObject and
/// the router is a plain observable Swift class.
private final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        guard let medication = userInfo["medication"] as? String else { return }
        let recall = userInfo["recall"] as? String
        await NotificationRouter.shared.received(medication: medication, recall: recall)
    }

    /// Show the banner even when the app is already open — otherwise a recall
    /// found while the person is using the app arrives silently.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
