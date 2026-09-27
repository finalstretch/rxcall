import SwiftUI
import MessageUI

/// Sends feedback by email from the person's own Mail account. Nothing goes
/// through us: the app just pre-fills the address, a subject, and the app
/// and iOS versions. Their medication list is never included.
struct FeedbackView: View {
    private static let address = "hello@finalstretch.org"

    @State private var showingComposer = false
    @State private var copied = false

    private var canMail: Bool { MFMailComposeViewController.canSendMail() }

    private var versionLine: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "Rxcall \(v) (\(b)) · iOS \(UIDevice.current.systemVersion) · \(UIDevice.current.model)"
    }

    private var body_: String {
        """


        —
        \(versionLine)
        (This line helps us find the problem. Your medication list is not included.)
        """
    }

    var body: some View {
        List {
            Section {
                Text("Something confusing, something broken, or something you wish it did — we read every message. Rxcall is built by two people, so replies can take a few days.")
            }

            Section {
                if canMail {
                    Button {
                        showingComposer = true
                    } label: {
                        Label("Email us", systemImage: "envelope")
                    }
                } else {
                    Link(destination: mailtoURL) {
                        Label("Email us", systemImage: "envelope")
                    }
                }
                Button {
                    UIPasteboard.general.string = Self.address
                    copied = true
                } label: {
                    Label(copied ? "Copied" : "Copy the address", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                LabeledContent("Address", value: Self.address)
                    .textSelection(.enabled)
            } footer: {
                Text("Opens your Mail app with the address and your app version filled in. Please don't include health details you'd rather not send by email — the medication name and what happened is plenty.")
            }

            Section {
                LabeledContent("Version", value: versionLine)
                    .font(.footnote)
            } header: {
                Text("Included in the email")
            }
        }
        .navigationTitle("Send feedback")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingComposer) {
            MailComposer(to: Self.address, subject: "Rxcall feedback", body: body_)
                .ignoresSafeArea()
        }
    }

    private var mailtoURL: URL {
        var c = URLComponents(string: "mailto:\(Self.address)")!
        c.queryItems = [.init(name: "subject", value: "Rxcall feedback"), .init(name: "body", value: body_)]
        return c.url!
    }
}

private struct MailComposer: UIViewControllerRepresentable {
    let to: String
    let subject: String
    let body: String
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setToRecipients([to])
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        vc.mailComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: MFMailComposeViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }
        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult, error: Error?) {
            dismiss()
        }
    }
}
