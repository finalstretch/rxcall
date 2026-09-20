import SwiftUI
import SwiftData

/// Everything about one medication: what's on file, the recalls found for it,
/// and the way to remove it.
struct MedicationDetailView: View {
    @Bindable var medication: Medication
    let onDelete: () -> Void

    @Environment(RecallStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false
    @State private var showingAll = false
    @State private var about: DrugInfo?
    @State private var aboutLoaded = false

    private var matches: [RecallMatch]? { store.matches(for: medication) }

    /// Long lists (levothyroxine has 60+ ongoing recalls) show the ones that
    /// matter most and fold the rest away. Everything certain, new, or naming
    /// the bottle's strength stays visible.
    private let visibleLimit = 5
    private func visible(_ all: [RecallMatch]) -> [RecallMatch] {
        if showingAll || all.count <= visibleLimit { return all }
        let important = all.filter { $0.confidence == .ndc || $0.mentionsStrength || !medication.hasSeen($0.recall) }
        var out = Array(all.prefix(visibleLimit))
        for m in important where !out.contains(m) { out.append(m) }
        return all.filter { out.contains($0) }
    }

    var body: some View {
        List {
            Section {
                if let generic = medication.genericName, generic.lowercased() != medication.name.lowercased() {
                    LabeledContent("Generic", value: generic)
                }
                LabeledContent("Added", value: medication.addedAt.formatted(date: .abbreviated, time: .omitted))
            }

            Section {
                TextField("Strength", text: optional($medication.strength), prompt: Text("e.g. 500 mg"))
                TextField("NDC", text: optional($medication.ndc), prompt: Text("Not entered"))
                    .keyboardType(.numbersAndPunctuation)
                TextField("Lot number", text: optional($medication.lotNumber), prompt: Text("Not entered"))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
            } header: {
                Text("From the bottle")
            } footer: {
                Text("With the NDC, Rx-call can tell you a recall definitely covers your bottle. The lot number is shown next to each recall's lot list so you can compare. Pharmacy labels usually don't print the lot — look on the box or the manufacturer's bottle near the expiry date, or ask your pharmacist.")
            }

            Section {
                Button {
                    Task { await store.check(medication) }
                } label: {
                    HStack {
                        Label(matches == nil ? "Check for recalls" : "Check again", systemImage: "arrow.clockwise")
                        Spacer()
                        if store.isChecking(medication) { ProgressView() }
                    }
                }
                .disabled(store.isChecking(medication))

                if let matches {
                    if matches.isEmpty {
                        Label("No ongoing recalls found", systemImage: "checkmark.circle")
                            .foregroundStyle(.secondary)
                    } else {
                        let shown = visible(matches)
                        ForEach(shown) { match in
                            NavigationLink(value: match) {
                                RecallRow(match: match, isNew: !medication.hasSeen(match.recall))
                            }
                        }
                        if shown.count < matches.count {
                            Button("Show \(matches.count - shown.count) more") { showingAll = true }
                        } else if showingAll && matches.count > visibleLimit {
                            Button("Show fewer") { showingAll = false }
                        }
                    }
                } else if !store.isChecking(medication) {
                    Text("Not checked yet.")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Recalls")
            } footer: {
                if let at = store.checkedAt(medication) {
                    Text("Checked \(at, format: .relative(presentation: .named)).")
                }
            }

            if let about {
                Section {
                    Text(about.summary)
                    Link(destination: about.url) {
                        Label("Read more on MedlinePlus", systemImage: "arrow.up.right.square")
                    }
                } header: {
                    Text("About \(about.title)")
                } footer: {
                    Text("From MedlinePlus, the National Library of Medicine. General information, not advice about your situation.")
                }
            }

            Section {
                Button("Remove medication", role: .destructive) { confirmingDelete = true }
                    .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(medication.name)
        .navigationBarTitleDisplayMode(.large)
        .task {
            guard !aboutLoaded else { return }
            aboutLoaded = true
            about = await MedlinePlusClient.shared.info(for: medication)
        }
        .navigationDestination(for: RecallMatch.self) { match in
            RecallDetailView(match: match, medication: medication)
                .onAppear { store.markSeen(match, for: medication) }
        }
        .confirmationDialog("Remove \(medication.name)?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                onDelete()
                dismiss()
            }
        } message: {
            Text("Rx-call will stop checking recalls for it. You can add it again any time.")
        }
    }

    /// Binds an optional string field so an emptied text field stores nil.
    private func optional(_ source: Binding<String?>) -> Binding<String> {
        Binding(
            get: { source.wrappedValue ?? "" },
            set: { source.wrappedValue = $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 }
        )
    }
}

/// One recall in a list. Shared by the medication screen.
struct RecallRow: View {
    let match: RecallMatch
    var isNew = false
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: match.confidence == .ndc ? "exclamationmark.triangle.fill" : "questionmark.circle")
                    .accessibilityHidden(true)
                Text(match.confidence.label).font(.subheadline.weight(.semibold))
                if isNew {
                    Text("New")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                }
            }
            if match.mentionsStrength {
                Label("Mentions your strength", systemImage: "checkmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
