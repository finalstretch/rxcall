import SwiftUI

/// Shown once, on first launch. Can't be swiped away; the person has to read
/// it and tap through. A shorter version stays visible in the app footer.
///
/// The text scrolls and only the button is pinned, so that at the largest
/// accessibility text sizes nothing is pushed off the bottom of the screen.
struct NoticeView: View {
    let onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "pills")
                    .font(.system(size: 44))
                    .accessibilityHidden(true)
                Text("Before you start")
                    .font(.largeTitle.bold())
                Text("Rxcall shows you public recall notices from the U.S. Food and Drug Administration for medications you list. That's all it does.")
                Text("It is an **independent project** — not affiliated with the FDA — and it covers **medications sold in the United States**. If yours was bought somewhere else, Rxcall won't find recalls for it.")
                Text("It is **not medical advice**. It can't tell you whether to stop, start, or change a medication — only your pharmacist or doctor can.")
                Text("Your medication list stays on this phone. It's never sent anywhere.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 32)
        }
        .safeAreaInset(edge: .bottom) {
            Button("I understand") { onContinue() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(.bar)
        }
    }
}
