import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Medication.addedAt) private var medications: [Medication]
    @AppStorage("hasSeenNotice") private var hasSeenNotice = false

    @State private var showingAdd = false
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
            .navigationTitle("Rx-call")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAdd = true } label: {
                        Label("Add medication", systemImage: "plus")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { footer }
            .sheet(isPresented: $showingAdd) { AddMedicationView() }
            .sheet(isPresented: Binding(get: { !hasSeenNotice }, set: { _ in })) {
                NoticeView { hasSeenNotice = true }
                    .interactiveDismissDisabled()
            }
            #if DEBUG
            .task { if Demo.isActive { await store.checkAll(medications) } }
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
            Text("Add what you take and Rx-call will check the FDA's recall list for it. Your list stays on this phone.")
        } actions: {
            Button("Add medication") { showingAdd = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private var list: some View {
        List {
            ForEach(medications) { med in
                NavigationLink {
                    MedicationDetailView(medication: med) { delete(med) }
                } label: {
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
                    if let lastChecked = store.lastChecked {
                        Text("Last checked \(lastChecked, format: .relative(presentation: .named)).")
                    }
                    Text("Not medical advice. Talk to your pharmacist before changing any medication.")
                }
            }
        }
    }

    /// Only the button is pinned. Everything else scrolls with the list so
    /// that at accessibility text sizes the results aren't pushed off screen.
    private var footer: some View {
        Button {
            Task { await store.checkAll(medications) }
        } label: {
            if store.isCheckingAny {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                Text("Check for recalls").frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(store.isCheckingAny || medications.isEmpty)
        .padding()
        .background(.bar)
    }

    // MARK: - Actions

    private func delete(at offsets: IndexSet) {
        for i in offsets { delete(medications[i]) }
    }

    private func delete(_ medication: Medication) {
        store.forget(medication)
        context.delete(medication)
    }
}

/// One medication in the list, with a one-line recall status.
private struct MedicationRow: View {
    let medication: Medication
    let matches: [RecallMatch]?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(medication.name).font(.headline)
            if let generic = medication.genericName, generic.lowercased() != medication.name.lowercased() {
                Text(generic).font(.subheadline).foregroundStyle(.secondary)
            }
            Label(status.text, systemImage: status.symbol)
                .font(.subheadline)
                .foregroundStyle(status.warn ? Color.primary : Color.secondary)
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
