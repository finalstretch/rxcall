import SwiftUI
import SwiftData

struct AddMedicationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var picked: DrugEntry?
    @State private var ndc = ""
    @State private var lot = ""

    private var suggestions: [DrugEntry] {
        picked == nil ? DrugIndex.shared.suggestions(for: name) : []
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Medication name", text: $name)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: name) { _, _ in picked = nil }
                    ForEach(suggestions) { entry in
                        Button {
                            picked = entry
                            name = entry.displayName
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.displayName)
                                if let subtitle = entry.subtitle {
                                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                        .accessibilityHint("Use this name")
                    }
                    if let picked, let generic = picked.subtitle {
                        Label(generic, systemImage: "checkmark")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Generic or brand name, as it's written on the label — for example “metformin” or “Synjardy”. Pick a suggestion if one matches; you can also just type a name.")
                }
                Section {
                    TextField("NDC (optional)", text: $ndc)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Lot number (optional)", text: $lot)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                } header: {
                    Text("From the bottle")
                } footer: {
                    Text("The NDC is a code like 68462-521-90 printed on the label. Adding it lets Rx-call tell you a recall definitely covers your bottle, not just your medication.")
                }
            }
            .navigationTitle("Add medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let clean = { (s: String) -> String? in
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
        // If they picked from the index, search by the ingredient too. If they
        // typed something we don't know, search exactly what they typed.
        let generic = picked?.searchTerms.last
        context.insert(Medication(name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                  genericName: generic, ndc: clean(ndc), lotNumber: clean(lot)))
        dismiss()
    }
}
