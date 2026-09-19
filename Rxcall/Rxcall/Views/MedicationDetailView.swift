import SwiftUI
import SwiftData

/// Everything about one medication: what's on file, the recalls found for it,
/// and the way to remove it.
struct MedicationDetailView: View {
    @Bindable var medication: Medication
    /// nil = not checked yet this session.
    let matches: [RecallMatch]?
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false

    var body: some View {
        List {
            Section {
                if let generic = medication.genericName, generic.lowercased() != medication.name.lowercased() {
                    LabeledContent("Generic", value: generic)
                }
                LabeledContent("Added", value: medication.addedAt.formatted(date: .abbreviated, time: .omitted))
            }

            Section {
                TextField("NDC", text: optional($medication.ndc), prompt: Text("Not entered"))
                    .keyboardType(.numbersAndPunctuation)
                TextField("Lot number", text: optional($medication.lotNumber), prompt: Text("Not entered"))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
            } header: {
                Text("From the bottle")
            } footer: {
                Text("With the NDC, Rx-call can tell you a recall definitely covers your bottle. The lot number is shown next to each recall's lot list so you can compare.")
            }

            Section("Recalls") {
                if let matches {
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
                    Text("Not checked yet. Go back and tap Check for recalls.")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Remove medication", role: .destructive) { confirmingDelete = true }
                    .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(medication.name)
        .navigationBarTitleDisplayMode(.large)
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
