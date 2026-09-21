import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Medication.addedAt) private var medications: [Medication]
    @AppStorage("hasSeenNotice") private var hasSeenNotice = false

    /// One sheet slot. "Scan a bottle" goes straight to the camera (after the
    /// one-time tutorial); the add form only appears afterwards, pre-filled.
    /// Hand-offs go through onDismiss, since a sheet can't be presented while
    /// another is dismissing.
    private enum Sheet: Identifiable {
        case typing, tutorial, scanner, form(ScanResult), settings
        var id: String {
            switch self {
            case .typing: "typing"; case .tutorial: "tutorial"; case .scanner: "scanner"
            case .form: "form"; case .settings: "settings"
            }
        }
    }
    @State private var sheet: Sheet?
    @State private var nextSheet: Sheet?
    @AppStorage("hasSeenScanTutorial") private var hasSeenScanTutorial = false
    @State private var store = RecallStore()

    var body: some View {
        NavigationStack {
            Group {
                if medications.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Rxcall")
            // Every destination is registered here, at the root of the stack.
            // Declaring them inside pushed screens resolves unreliably.
            .navigationDestination(for: Medication.self) { med in
                MedicationDetailView(medication: med) { delete(med) }
            }
            .navigationDestination(for: RecallRoute.self) { route in
                RecallDetailView(match: route.match, medication: route.medication)
                    .onAppear { store.markSeen(route.match, for: route.medication) }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { sheet = .settings } label: {
                        Label("Settings", systemImage: "gear")
                    }
                }
                #if DEBUG
                ToolbarItem(placement: .secondaryAction) {
                    Button("Debug: run background check") {
                        Task { await runBackgroundCheck() }
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button("Debug: simulate a new recall") {
                        // Forget the newest cached recall so the next check treats it as new.
                        for med in medications where !med.cachedRecalls.isEmpty {
                            med.cachedRecalls = Array(med.cachedRecalls.dropFirst())
                        }
                        Task { await runBackgroundCheck() }
                    }
                }
                #endif
            }
            .safeAreaInset(edge: .bottom) { footer }
            .sheet(item: $sheet, onDismiss: {
                if let n = nextSheet { nextSheet = nil; sheet = n }
            }) { which in
                Group {
                    switch which {
                    case .typing:
                        AddMedicationView()
                    case .tutorial:
                        ScanTutorialView {
                            hasSeenScanTutorial = true
                            nextSheet = .scanner
                        }
                    case .scanner:
                        ScanView { result in nextSheet = .form(result) }
                    case .form(let result):
                        AddMedicationView(prefill: result)
                    case .settings:
                        SettingsView()
                    }
                }
                .textSized()
            }
            .sheet(isPresented: Binding(get: { !hasSeenNotice }, set: { _ in })) {
                NoticeView { hasSeenNotice = true }
                    .interactiveDismissDisabled()
                    .textSized()
            }
            #if DEBUG
            .task {
                if Demo.showsTutorial { sheet = .tutorial }
                if Demo.showsSettings { sheet = .settings }
                if Demo.isActive { await store.checkAll(medications) }
            }
            #endif
            .alert("Couldn't check", isPresented: Binding(get: { store.errorMessage != nil },
                                                          set: { if !$0 { store.errorMessage = nil } })) {
                Button("OK") {}
            } message: { Text(store.errorMessage ?? "") }
        }
        .environment(store)
    }

    // MARK: - Pieces

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No medications yet", systemImage: "pills")
        } description: {
            Text("Add what you take and Rxcall will check the FDA's recall list for it. Your list stays on this phone.")
        } actions: {
            VStack(spacing: 12) {
                Button {
                    sheet = hasSeenScanTutorial ? .scanner : .tutorial
                } label: {
                    Label("Scan a bottle", systemImage: "camera.viewfinder")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Button("Type a name instead") { sheet = .typing }
            }
        }
    }

    private var list: some View {
        List {
            ForEach(medications) { med in
                NavigationLink(value: med) {
                    MedicationRow(medication: med, matches: store.matches(for: med))
                }
                // Swipe from either edge to remove; a full swipe does it in one go.
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button(role: .destructive) { delete(med) } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
            }
            .onDelete(perform: delete)

            Section {
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    if let lastChecked = store.lastChecked(medications) {
                        Text("Last checked \(lastChecked, format: .relative(presentation: .named)).")
                    }
                    Text("Not medical advice. Talk to your pharmacist before changing any medication.")
                }
            }
        }
    }

    /// Only the buttons are pinned. Everything else scrolls with the list so
    /// that at accessibility text sizes the results aren't pushed off screen.
    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                Task { await store.checkAll(medications) }
            } label: {
                if store.isCheckingAny {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text("Check for recalls").frame(maxWidth: .infinity)
                }
            }
            .disabled(store.isCheckingAny || medications.isEmpty)

            Button { sheet = .typing } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .frame(minWidth: 28)
            }
            .accessibilityLabel("Add medication")
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding()
        .background(.bar)
    }

    // MARK: - Actions

    #if DEBUG
    private func runBackgroundCheck() async {
        let n = await BackgroundRefresh.checkAllAndNotify(container: context.container)
        store.errorMessage = n.map { "Background check ran: \($0) new recall(s). Notifications arrive in a moment." }
            ?? "Background check failed (network)."
    }
    #endif

    private func delete(at offsets: IndexSet) {
        for i in offsets { delete(medications[i]) }
    }

    private func delete(_ medication: Medication) {
        context.delete(medication)
    }
}

/// One medication in the list, with a one-line recall status.
private struct MedicationRow: View {
    let medication: Medication
    let matches: [RecallMatch]?
    var unseen: Int { (matches ?? []).filter { !medication.hasSeen($0.recall) }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(medication.name).font(.headline)
            if let generic = medication.genericName, generic.lowercased() != medication.name.lowercased() {
                Text(generic).font(.subheadline).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Label(status.text, systemImage: status.symbol)
                    .font(.subheadline)
                    .foregroundStyle(status.warn ? Color.primary : Color.secondary)
                if unseen > 0 {
                    Text("\(unseen) new")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var status: (text: String, symbol: String, warn: Bool) {
        guard let matches else { return ("Not checked yet", "circle.dotted", false) }
        if matches.isEmpty { return ("No ongoing recalls", "checkmark.circle", false) }
        if matches.contains(where: { $0.confidence == .ndc }) {
            return ("Recall matches your bottle", "exclamationmark.triangle.fill", true)
        }
        let n = matches.count
        return ("\(n) possible \(n == 1 ? "match" : "matches") — check lot numbers", "questionmark.circle", true)
    }
}

#Preview {
    ContentView().modelContainer(for: Medication.self, inMemory: true)
}
