import SwiftUI

/// Shown once, on first launch. Can't be swiped away; the person has to read
/// it and tap through. A shorter version stays visible in the app footer.
struct NoticeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()
            Image(systemName: "pills")
                .font(.system(size: 44))
                .accessibilityHidden(true)
            Text("Before you start")
                .font(.largeTitle.bold())
            Text("Rx-call shows you public recall notices from the FDA for medications you list. That's all it does.")
            Text("It is **not medical advice**. It can't tell you whether to stop, start, or change a medication — only your pharmacist or doctor can.")
            Text("Your medication list stays on this phone. It's never sent anywhere.")
            Spacer()
            Button("I understand") { onContinue() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
        }
        .padding(24)
    }
}
