import SwiftUI
import SwiftData

struct AddMedicationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name: String
    @State private var picked: DrugEntry?
    @State private var ndc: String
    @State private var lot: String
    @State private var strength: String

    /// Empty form, or one pre-filled from a scan done before the form opened.
    init(prefill: ScanResult? = nil) {
        _name = State(initialValue: prefill?.entry?.displayName ?? "")
        _picked = State(initialValue: prefill?.entry)
        _ndc = State(initialValue: prefill?.ndc ?? "")
        _lot = State(initialValue: prefill?.lotNumber ?? "")
        _strength = State(initialValue: prefill?.strength ?? "")
    }
    /// One sheet slot: the tutorial hands off to the camera via onDismiss,
    /// since presenting a new sheet while one is dismissing doesn't work.
    private enum Sheet: String, Identifiable { case tutorial, scanner; var id: String { rawValue } }
    @State private var sheet: Sheet?
    @State private var scanAfterTutorial = false
    @AppStorage("hasSeenScanTutorial") private var hasSeenScanTutorial = false

    private var suggestions: [DrugEntry] {
        picked == nil ? DrugIndex.shared.suggestions(for: name) : []
    }

    var body: some View {
        NavigationStack {
            Form {
                // What's about to be added, so a scan result is unmissable.
                if !name.trimmingCharacters(in: .whitespaces).isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Adding")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            Text(name)
                                .font(.title2.bold())
                            if let generic = picked?.subtitle {
                                Text(generic)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            if !strength.isEmpty || !ndc.isEmpty || !lot.isEmpty {
                                Text([strength.isEmpty ? nil : strength,
                                      ndc.isEmpty ? nil : "NDC \(ndc)",
                                      lot.isEmpty ? nil : "Lot \(lot)"]
                                    .compactMap { $0 }.joined(separator: " · "))
                                    .font(.footnote.monospaced())
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 2)
                            }
                        }
                        .padding(.vertical, 4)
                        .accessibilityElement(children: .combine)
                    } footer: {
                        Text("Check this matches the label, then tap Add.")
                    }
                }
                Section {
                    Button {
                        startScan()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "camera.viewfinder")
                            Text(picked == nil && name.isEmpty ? "Scan the label with the camera" : "Scan again")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                } footer: {
                    Text("Reads the name, strength, NDC, and lot number off the bottle or box.")
                }
                Section {
                    TextField("Medication name", text: $name)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        // Typing something different forgets the picked entry;
                        // the scan or a suggestion setting the name doesn't.
                        .onChange(of: name) { _, new in
                            if let p = picked, p.displayName != new { picked = nil }
                        }
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
                } header: {
                    Text(name.isEmpty ? "Or type it" : "Name")
                } footer: {
                    Text("Generic or brand name, as it's written on the label — for example “metformin” or “Synjardy”. Pick a suggestion if one matches; you can also just type a name.")
                }
                Section {
                    TextField("Strength (optional)", text: $strength, prompt: Text("Strength, e.g. 500 mg"))
                    TextField("NDC (optional)", text: $ndc)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Lot number (optional)", text: $lot)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                } header: {
                    Text("From the bottle")
                } footer: {
                    Text("The NDC is a code like 68462-521-90 — on the pharmacy label if you're lucky, otherwise on the box by the barcode. Adding it lets Rxcall tell you a recall definitely covers your bottle, not just your medication.")
                }
            }
            .navigationTitle("Add medication")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $sheet, onDismiss: {
                if scanAfterTutorial { scanAfterTutorial = false; sheet = .scanner }
            }) { which in
                switch which {
                case .tutorial:
                    ScanTutorialView {
                        hasSeenScanTutorial = true
                        scanAfterTutorial = true
                    }
                case .scanner:
                    scanner
                }
            }
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

    private var scanner: some View {
        ScanView { result in
            if let entry = result.entry {
                picked = entry
                name = entry.displayName
            }
            if let code = result.ndc, ndc.isEmpty { ndc = code }
            if let code = result.lotNumber, lot.isEmpty { lot = code }
            if let s = result.strength, strength.isEmpty { strength = s }
        }
    }

    /// First time through, show how it works; after that, straight to the camera.
    private func startScan() {
        sheet = hasSeenScanTutorial ? .scanner : .tutorial
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
                                  genericName: generic, ndc: clean(ndc), lotNumber: clean(lot),
                                  strength: clean(strength)))
        Notifications.requestPermissionIfNeeded()
        dismiss()
    }
}
