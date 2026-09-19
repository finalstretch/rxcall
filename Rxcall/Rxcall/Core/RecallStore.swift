import Foundation
import SwiftData

/// Recall results, shared by the list and the medication screens so a check
/// started from either shows on both. The last successful result for each
/// medication is cached on the medication itself, so there's something to
/// show offline and new recalls can be told from ones already seen.
@Observable
@MainActor
final class RecallStore {
    private(set) var checking: Set<PersistentIdentifier> = []
    var errorMessage: String?
    /// Bumped after every check so views re-read the cache on the model.
    private(set) var version = 0

    private let client = OpenFDAClient()

    /// nil = never checked.
    func matches(for medication: Medication) -> [RecallMatch]? {
        _ = version
        guard medication.lastCheckedAt != nil else { return nil }
        return RecallMatcher.matches(for: medication, in: medication.cachedRecalls)
    }

    func checkedAt(_ medication: Medication) -> Date? {
        _ = version
        return medication.lastCheckedAt
    }

    func isChecking(_ medication: Medication) -> Bool {
        checking.contains(medication.persistentModelID)
    }

    var isCheckingAny: Bool { !checking.isEmpty }

    /// Most recent check across the given medications, for the list footer.
    func lastChecked(_ medications: [Medication]) -> Date? {
        _ = version
        return medications.compactMap(\.lastCheckedAt).max()
    }

    /// Recalls the person hasn't opened yet.
    func unseen(for medication: Medication) -> [RecallMatch] {
        (matches(for: medication) ?? []).filter { !medication.hasSeen($0.recall) }
    }

    func check(_ medication: Medication) async {
        let id = medication.persistentModelID
        checking.insert(id)
        defer { checking.remove(id) }
        do {
            medication.cachedRecalls = try await client.ongoingRecalls(for: medication)
            medication.lastCheckedAt = .now
            version += 1
        } catch {
            errorMessage = medication.lastCheckedAt == nil
                ? "Couldn't reach the FDA's recall service. Check your connection and try again."
                : "Couldn't reach the FDA's recall service. Showing the results from the last check."
        }
    }

    func checkAll(_ medications: [Medication]) async {
        for medication in medications {
            await check(medication)
            if errorMessage != nil { return }
        }
    }

    func markSeen(_ match: RecallMatch, for medication: Medication) {
        medication.markSeen(match.recall)
        version += 1
    }
}
