import SwiftUI
import SwiftData

/// The app's text-size preference. "System" follows the iPhone setting;
/// the others override it, for people who never found that setting.
enum TextSizeChoice: String, CaseIterable, Identifiable {
    case system, large, extraLarge, huge
    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "Same as iPhone"
        case .large: "Large"
        case .extraLarge: "Extra large"
        case .huge: "Huge"
        }
    }

    /// nil means don't override.
    var dynamicTypeSize: DynamicTypeSize? {
        switch self {
        case .system: nil
        case .large: .xLarge
        case .extraLarge: .xxxLarge
        case .huge: .accessibility2
        }
    }
}

struct SettingsView: View {
    @AppStorage("textSize") private var textSize = TextSizeChoice.system.rawValue
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var medications: [Medication]
    @State private var showingTutorial = false
    @State private var confirmingRemoveAll = false

    private var choice: Binding<TextSizeChoice> {
        Binding(get: { TextSizeChoice(rawValue: textSize) ?? .system },
                set: { textSize = $0.rawValue })
    }

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Text size", selection: choice) {
                        ForEach(TextSizeChoice.allCases) { c in
                            Text(c.label).tag(c)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Text size")
                } footer: {
                    Text("Changes the size of text throughout Rxcall. \"Same as iPhone\" uses the size set in Settings → Display & Brightness → Text Size, which also affects your other apps.")
                }

                Section("Help") {
                    Button {
                        showingTutorial = true
                    } label: {
                        Label("How to scan a bottle", systemImage: "camera.viewfinder")
                    }
                    NavigationLink {
                        FeedbackView()
                    } label: {
                        Label("Send feedback", systemImage: "envelope")
                    }
                    Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                        Label("Camera and notification permissions", systemImage: "gear")
                    }
                }

                Section {
                    NavigationLink {
                        DataSourcesView()
                    } label: {
                        Label("Where the information comes from", systemImage: "building.columns")
                    }
                } header: {
                    Text("Data and privacy")
                } footer: {
                    Text("Rxcall has no account and no server. The only thing it ever sends anywhere is the name of a medication, to look up recalls and information about it.")
                }

                Section {
                    LabeledContent("Version", value: version)
                    Link(destination: URL(string: "https://finalstretch.org")!) {
                        Label("The Final Stretch Project", systemImage: "globe")
                    }
                    Link(destination: URL(string: "https://github.com/finalstretch/rxcall")!) {
                        Label("Source code", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                } header: {
                    Text("About")
                } footer: {
                    Text("Rxcall is a free, open-source project. It shows public recall notices from the FDA for medications you list. It is not medical advice: it can't tell you whether to stop, start, or change a medication — only your pharmacist or doctor can. It does not diagnose, recommend treatment, or interpret test results.")
                }

                if !medications.isEmpty {
                    Section {
                        Button("Remove all medications", role: .destructive) { confirmingRemoveAll = true }
                            .frame(maxWidth: .infinity)
                    } footer: {
                        Text("Deletes your list from this phone. Nothing else needs deleting — there's no copy anywhere else.")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingTutorial) { ScanTutorialView {}.textSized() }
            .confirmationDialog(
                "Remove all \(medications.count) medication\(medications.count == 1 ? "" : "s")?",
                isPresented: $confirmingRemoveAll, titleVisibility: .visible
            ) {
                Button("Remove all", role: .destructive) {
                    for med in medications { context.delete(med) }
                    dismiss()
                }
            } message: {
                Text("Rxcall will stop checking recalls for them. This can't be undone, but you can add them again any time.")
            }
        }
    }
}

/// Credits, and the plain-language version of the privacy model.
private struct DataSourcesView: View {
    var body: some View {
        List {
            Section {
                Text("Every recall shown in Rxcall comes from the U.S. Food and Drug Administration's public enforcement reports, through the openFDA service. Rxcall doesn't change them — it explains them.")
                Link("openFDA drug recalls", destination: URL(string: "https://open.fda.gov/apis/drug/enforcement/")!)
            } header: {
                Text("Recalls")
            }

            Section {
                Text("Descriptions of what a medication is for come from MedlinePlus, the National Library of Medicine's patient information service, with names matched through its RxNorm database.")
                Link("MedlinePlus drug information", destination: URL(string: "https://medlineplus.gov/druginformation.html")!)
            } header: {
                Text("About each medication")
            }

            Section {
                Text("The list of drug names Rxcall recognises when you type or scan is built from the FDA's National Drug Code directory and stored inside the app, so scanning a label never sends the label anywhere.")
            } header: {
                Text("Drug names")
            }

            Section {
                Text("When you check for recalls or open a medication, your phone asks the FDA and the National Library of Medicine directly about that medication by name. Nothing about you goes with it: no account, no identifier, no location, and never the text of a label. Your medication list, lot numbers, and what you've read stay on this phone.")
            } header: {
                Text("What leaves your phone")
            }
        }
        .navigationTitle("Where it comes from")
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension View {
    /// Applies the app's text-size setting. Needed at the window root and on
    /// every sheet: presented sheets don't inherit the override.
    func textSized() -> some View { modifier(TextSizeModifier()) }
}

/// Applies the chosen text size to everything beneath it.
struct TextSizeModifier: ViewModifier {
    @AppStorage("textSize") private var textSize = TextSizeChoice.system.rawValue
    @Environment(\.dynamicTypeSize) private var systemSize

    func body(content: Content) -> some View {
        // Always the same modifier, so changing the setting doesn't swap the
        // view tree (which would tear down whatever sheet is open).
        content.dynamicTypeSize((TextSizeChoice(rawValue: textSize) ?? .system).dynamicTypeSize ?? systemSize)
    }
}
