import SwiftUI
import SwiftData

struct AddMedicationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var ndc = ""
    @State private var lot = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Medication name", text: $name)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text("Generic or brand name, as it's written on the label — for example “metformin” or “Synjardy”.")
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
        context.insert(Medication(name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                  ndc: clean(ndc), lotNumber: clean(lot)))
        dismiss()
    }
}
