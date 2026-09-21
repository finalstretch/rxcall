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

    @Environment(\.scenePhase) private var scenePhase

    init() {
        BackgroundRefresh.register(container: container)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .textSized()
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { BackgroundRefresh.schedule() }
        }
    }
}

#if DEBUG
/// Launch with `-demo metformin,lisinopril` to start with those medications,
/// skip the first-run notice, and run a check immediately. For screenshots
/// and simulator runs from the command line; compiled out of release builds.
enum Demo {
    static var isActive: Bool { medicationNames != nil }

    /// `-tutorial`: forget that the scan tutorial was seen and open the scan flow.
    static var showsTutorial: Bool { ProcessInfo.processInfo.arguments.contains("-tutorial") }
    /// `-settings`: open the settings sheet on launch.
    static var showsSettings: Bool { ProcessInfo.processInfo.arguments.contains("-settings") }

    static var medicationNames: [String]? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-demo"), i + 1 < args.count else { return nil }
        return args[i + 1].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    @MainActor
    static func seedIfRequested(into container: ModelContainer) {
        if showsTutorial {
            UserDefaults.standard.set(true, forKey: "hasSeenNotice")
            UserDefaults.standard.set(false, forKey: "hasSeenScanTutorial")
        }
        guard let names = medicationNames else { return }
        UserDefaults.standard.set(true, forKey: "hasSeenNotice")
        let context = container.mainContext
        let existing = (try? context.fetch(FetchDescriptor<Medication>())) ?? []
        for name in names {
            // Resolve through the index the way picking a suggestion would.
            let entry = DrugIndex.shared.suggestions(for: name, limit: 1).first
            let resolved = entry?.displayName ?? name
            if existing.contains(where: { $0.name.caseInsensitiveCompare(resolved) == .orderedSame }) { continue }
            context.insert(Medication(name: entry?.displayName ?? name,
                                      genericName: entry?.searchTerms.last))
        }
    }
}
#endif
