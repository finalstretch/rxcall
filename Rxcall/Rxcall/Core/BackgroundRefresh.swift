import BackgroundTasks
import Foundation
import SwiftData
import UserNotifications

/// Checks every medication for recalls while the app isn't open, and posts a
/// local notification when a recall appears that wasn't there last time.
///
/// Everything stays on the phone: the check is the same direct request to
/// api.fda.gov the app makes when tapped, and the notification is generated
/// locally — there's no push server. iOS decides when refresh actually runs
/// (typically a few times a day if the person uses the app regularly, and
/// only if Background App Refresh is on for it).
enum BackgroundRefresh {
    static let taskIdentifier = "org.finalstretch.rxcall.refresh"

    /// Must be called before the app finishes launching.
    static func register(container: ModelContainer) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            let refresh = task as! BGAppRefreshTask
            let work = Task { @MainActor in
                let found = await checkAllAndNotify(container: container)
                refresh.setTaskCompleted(success: found != nil)
            }
            refresh.expirationHandler = { work.cancel() }
            schedule()   // keep the chain going
        }
    }

    /// Ask for the next run. Harmless to call repeatedly; the system keeps one.
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 12 * 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Runs the checks. Returns the number of new recalls found, or nil if the
    /// network failed. Also used by the DEBUG "run now" menu item.
    @MainActor
    @discardableResult
    static func checkAllAndNotify(container: ModelContainer) async -> Int? {
        let context = container.mainContext
        guard let medications = try? context.fetch(FetchDescriptor<Medication>()) else { return 0 }
        let client = OpenFDAClient()
        var newCount = 0
        for medication in medications {
            guard !Task.isCancelled else { return nil }
            let before = Set(medication.cachedRecalls.map(\.recallNumber))
            guard let recalls = try? await client.ongoingRecalls(for: medication) else { return nil }
            let matches = RecallMatcher.matches(for: medication, in: recalls)
            let fresh = matches.filter { !before.contains($0.recall.recallNumber) }
            medication.cachedRecalls = recalls
            medication.lastCheckedAt = .now
            // First-ever check for a medication isn't "new recalls appeared";
            // the person sees those when they open the app.
            if !before.isEmpty, !fresh.isEmpty {
                await Notifications.post(for: medication, new: fresh)
                newCount += fresh.count
            }
        }
        try? context.save()
        return newCount
    }
}

enum Notifications {
    /// Asked once the person has something worth being told about — their
    /// first medication — not on first launch.
    static func requestPermissionIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    @MainActor
    static func post(for medication: Medication, new: [RecallMatch]) async {
        let content = UNMutableNotificationContent()
        let certain = new.contains { $0.confidence == .ndc }
        let n = new.count
        content.title = certain
            ? "Recall matches your \(medication.name)"
            : "New recall for \(medication.name)"
        if let first = new.first {
            let product = first.recall.productDescription.prefix(90)
            content.body = n == 1
                ? "\(product)… Open Rx-call to check the lot number."
                : "\(n) new recalls. Open Rx-call to check the lot numbers."
        }
        content.sound = .default
        content.userInfo = ["medication": medication.name]
        let request = UNNotificationRequest(
            identifier: "recall-\(medication.persistentModelID.hashValue)",
            content: content,
            trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
