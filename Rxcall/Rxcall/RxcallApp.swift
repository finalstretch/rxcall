import SwiftUI
import SwiftData

@main
struct RxcallApp: App {
    // The medication list is the only persisted user data, and it lives
    // in this on-device store. There is no server and no sync.
    let container: ModelContainer = {
        let container = try! ModelContainer(for: Medication.self)
        #if DEBUG
        Demo.seedIfRequested(into: container)
        #endif
        return container
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}

#if DEBUG
/// Launch with `-demo metformin,lisinopril` to start with those medications,
/// skip the first-run notice, and run a check immediately. For screenshots
/// and simulator runs from the command line; compiled out of release builds.
enum Demo {
    static var isActive: Bool { medicationNames != nil }

    static var medicationNames: [String]? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-demo"), i + 1 < args.count else { return nil }
        return args[i + 1].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    @MainActor
    static func seedIfRequested(into container: ModelContainer) {
        guard let names = medicationNames else { return }
        UserDefaults.standard.set(true, forKey: "hasSeenNotice")
        let context = container.mainContext
        let existing = (try? context.fetch(FetchDescriptor<Medication>())) ?? []
        for name in names where !existing.contains(where: { $0.name == name }) {
            context.insert(Medication(name: name))
        }
    }
}
#endif
