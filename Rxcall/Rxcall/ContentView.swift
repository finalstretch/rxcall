import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Medication.addedAt) private var medications: [Medication]
    @AppStorage("hasSeenNotice") private var hasSeenNotice = false

    @State private var showingAdd = false
    @State private var results: [PersistentIdentifier: [RecallMatch]] = [:]
    @State private var checking = false
    @State private var lastChecked: Date?
    @State private var errorMessage: String?

    private let client = OpenFDAClient()

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
            .task { if Demo.isActive { await checkAll() } }
            #endif
            .alert("Couldn't check", isPresented: Binding(get: { errorMessage != nil },
                                                          set: { if !$0 { errorMessage = nil } })) {
                Button("OK") {}
            } message: { Text(errorMessage ?? "") }
        }
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
                Section {
                    if let matches = results[med.persistentModelID] {
                        if matches.isEmpty {
                            Label("No ongoing recalls found", systemImage: "checkmark.circle")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(matches) { match in
                                NavigationLink(value: match) {
                                    RecallRow(match: match)
                                }
                            }
                        }
                    } else {
                        Text("Not checked yet")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    MedicationHeader(medication: med)
                }
            }
            .onDelete(perform: delete)

            Section {
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    if let lastChecked {
                        Text("Last checked \(lastChecked, format: .relative(presentation: .named)).")
                    }
                    Text("Not medical advice. Talk to your pharmacist before changing any medication.")
                }
            }
        }
        .navigationDestination(for: RecallMatch.self) { match in
            RecallDetailView(match: match)
        }
    }

    /// Only the button is pinned. Everything else scrolls with the list so
    /// that at accessibility text sizes the results aren't pushed off screen.
    private var footer: some View {
        Button {
            Task { await checkAll() }
        } label: {
            if checking {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                Text("Check for recalls").frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(checking || medications.isEmpty)
        .padding()
        .background(.bar)
    }

    // MARK: - Actions

    private func checkAll() async {
        checking = true
        defer { checking = false }
        var new: [PersistentIdentifier: [RecallMatch]] = [:]
        for med in medications {
            do {
                let recalls = try await client.ongoingRecalls(mentioning: med.name)
                new[med.persistentModelID] = RecallMatcher.matches(for: med, in: recalls)
            } catch {
                errorMessage = "Couldn't reach the FDA's recall service. Check your connection and try again."
                return
            }
        }
        results = new
        lastChecked = .now
    }

    private func delete(at offsets: IndexSet) {
        for i in offsets { context.delete(medications[i]) }
    }
}

private struct MedicationHeader: View {
    let medication: Medication
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(medication.name).font(.headline).textCase(nil)
            if medication.ndc != nil || medication.lotNumber != nil {
                Text([medication.ndc.map { "NDC \($0)" }, medication.lotNumber.map { "Lot \($0)" }]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).textCase(nil)
            }
        }
    }
}

private struct RecallRow: View {
    let match: RecallMatch
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: match.confidence == .ndc ? "exclamationmark.triangle.fill" : "questionmark.circle")
                    .accessibilityHidden(true)
                Text(match.confidence.label).font(.subheadline.weight(.semibold))
            }
            Text(match.recall.productDescription)
                .font(.subheadline)
                .lineLimit(2)
            HStack {
                Text(match.recall.classificationSummary.title)
                if let d = match.recall.initiationDate {
                    Text("·").accessibilityHidden(true)
                    Text(d, format: .dateTime.month().day().year())
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ContentView().modelContainer(for: Medication.self, inMemory: true)
}
