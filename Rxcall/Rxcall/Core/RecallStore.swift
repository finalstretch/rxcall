import Foundation
import SwiftData

/// Recall results for this session, shared by the list and the medication
/// screens so a check started from either shows up in both. Results aren't
/// persisted: they're re-fetched on demand and go stale fast.
@Observable
@MainActor
final class RecallStore {
    private(set) var results: [PersistentIdentifier: [RecallMatch]] = [:]
    private(set) var checkedAt: [PersistentIdentifier: Date] = [:]
    private(set) var checking: Set<PersistentIdentifier> = []
    var errorMessage: String?

    private let client = OpenFDAClient()

    /// nil = not checked yet this session.
    func matches(for medication: Medication) -> [RecallMatch]? {
        results[medication.persistentModelID]
    }

    func checkedAt(_ medication: Medication) -> Date? {
        checkedAt[medication.persistentModelID]
    }

    func isChecking(_ medication: Medication) -> Bool {
        checking.contains(medication.persistentModelID)
    }

    var isCheckingAny: Bool { !checking.isEmpty }

    /// Most recent check across all medications, for the list footer.
    var lastChecked: Date? { checkedAt.values.max() }

    func check(_ medication: Medication) async {
        let id = medication.persistentModelID
        checking.insert(id)
        defer { checking.remove(id) }
        do {
            let recalls = try await client.ongoingRecalls(for: medication)
            results[id] = RecallMatcher.matches(for: medication, in: recalls)
            checkedAt[id] = .now
        } catch {
            errorMessage = "Couldn't reach the FDA's recall service. Check your connection and try again."
        }
    }

    func checkAll(_ medications: [Medication]) async {
        for medication in medications {
            await check(medication)
            if errorMessage != nil { return }
        }
    }

    func forget(_ medication: Medication) {
        results[medication.persistentModelID] = nil
        checkedAt[medication.persistentModelID] = nil
    }
}
