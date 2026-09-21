import SwiftUI

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

    private var choice: Binding<TextSizeChoice> {
        Binding(get: { TextSizeChoice(rawValue: textSize) ?? .system },
                set: { textSize = $0.rawValue })
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

                Section {
                    Text("This is what text will look like. Recalls, medication names, and instructions all use this size.")
                } header: {
                    Text("Preview")
                }

                Section {
                    Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                        Label("Open iPhone settings for Rxcall", systemImage: "gear")
                    }
                } footer: {
                    Text("Camera and notification permissions live there.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
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

    func body(content: Content) -> some View {
        if let size = (TextSizeChoice(rawValue: textSize) ?? .system).dynamicTypeSize {
            content.dynamicTypeSize(size)
        } else {
            content
        }
    }
}
