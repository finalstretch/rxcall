import SwiftUI
import VisionKit

/// What a scan hands back to the add form.
struct ScanResult {
    var entry: DrugEntry?
    var ndc: String?
    var lotNumber: String?
    var strength: String?
}

/// Live camera scan of a medication label. Everything the camera sees is
/// processed on the phone by VisionKit and matched against the bundled drug
/// index; no image or text leaves the device.
struct ScanView: View {
    let onFinish: (ScanResult) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var scan = ScanAccumulator()
    @State private var showingHelp = false
    @State private var tick = Date()   // re-evaluates the stall check every second
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var canScan: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if canScan {
                    ZStack {
                        LabelScanner(scan: scan)
                        overlay
                    }
                    .ignoresSafeArea(edges: .horizontal)
                } else {
                    ContentUnavailableView("Scanning needs a camera",
                                           systemImage: "camera",
                                           description: Text("This device can't scan labels. You can still type the name."))
                }
                panel
            }
            .navigationTitle("Scan the label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showingHelp = true } label: {
                        Label("How to scan", systemImage: "questionmark.circle")
                    }
                }
            }
            .sheet(isPresented: $showingHelp) { ScanTutorialView {} }
            .onReceive(clock) { tick = $0 }
            .onChange(of: scan.isStable) { _, found in if found { haptic(.success) } }
            .onChange(of: scan.ndc) { _, v in if v != nil { haptic(.success) } }
            .onChange(of: scan.lotNumber) { _, v in if v != nil { haptic(.success) } }
        }
    }

    // MARK: - Live guidance over the camera

    private var overlay: some View {
        VStack {
            HStack(spacing: 8) {
                chip("Name", done: scan.isStable, partial: scan.leader != nil)
                chip("NDC", done: scan.ndc != nil, partial: false)
                chip("Lot", done: scan.lotNumber != nil, partial: false)
            }
            .padding(.top, 12)
            Spacer()
        }
    }

    /// What to do next. Lives in the panel, not over the camera, so it never
    /// collides with the chips when the camera area is short.
    private var guidanceRow: some View {
        HStack(spacing: 12) {
            Image(systemName: guidance.symbol)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.pulse, options: .repeating, isActive: guidance.animate)
                .frame(width: 28)
                .accessibilityHidden(true)
            Text(guidance.text)
                .font(.subheadline.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityAddTraits(.updatesFrequently)
    }

    private func chip(_ label: String, done: Bool, partial: Bool) -> some View {
        Label(label, systemImage: done ? "checkmark.circle.fill" : (partial ? "circle.dotted.circle" : "circle.dotted"))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(done ? Color.green : Color.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.black.opacity(0.55), in: Capsule())
            .accessibilityLabel("\(label): \(done ? "found" : (partial ? "reading" : "not found yet"))")
    }

    /// What to tell the person right now. The stall check depends on `tick`
    /// so it's re-evaluated even when the camera reads nothing new.
    private var guidance: (text: String, symbol: String, animate: Bool) {
        _ = tick
        if scan.framesSeen == 0 || scan.lastNewReadAt == nil {
            return ("Point the camera at the label.", "camera.viewfinder", false)
        }
        if scan.isStable && scan.ndc != nil && scan.lotNumber != nil {
            return ("All set — tap Use.", "checkmark.circle.fill", false)
        }
        if scan.isStalled {
            if scan.isStable && (scan.lotNumber == nil || scan.ndc == nil) {
                let missing = [scan.ndc == nil ? "NDC" : nil, scan.lotNumber == nil ? "lot number" : nil]
                    .compactMap { $0 }.joined(separator: " or ")
                return ("Pharmacy labels often leave out the \(missing). Check the box or the manufacturer's bottle — the NDC is by the barcode, the lot next to the expiry date.",
                        "shippingbox", true)
            }
            if scan.isStable {
                return ("Nothing new here. Try the other side of the label, or tilt the bottle away from the glare.",
                        "arrow.trianglehead.2.clockwise.rotate.90", true)
            }
            return ("Can't make out the name yet. Turn to where the drug name is printed, or move a little closer.",
                    "arrow.trianglehead.2.clockwise.rotate.90", true)
        }
        if !scan.isStable {
            return ("Slowly turn the bottle.", "arrow.trianglehead.2.clockwise.rotate.90", true)
        }
        let missing = [scan.ndc == nil ? "NDC" : nil, scan.lotNumber == nil ? "lot number" : nil]
            .compactMap { $0 }.joined(separator: " and ")
        return ("Got the name. Now turn to the other side for the \(missing) — usually near the barcode.",
                "arrow.trianglehead.2.clockwise.rotate.90", true)
    }

    private func haptic(_ kind: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(kind)
    }

    // MARK: - Findings and the Use button

    private var panel: some View {
        VStack(alignment: .leading, spacing: 12) {
            if canScan { guidanceRow }
            slot("Medication", value: scan.leader?.displayName, found: scan.isStable)
            slot("Strength", value: scan.strength, found: scan.strength != nil)
            slot("NDC", value: scan.ndc, found: scan.ndc != nil)
            slot("Lot number", value: scan.lotNumber, found: scan.lotNumber != nil)

            // Runners-up with real support, so a wrong guess is one tap from fixed.
            let alternatives = scan.candidates.dropFirst().filter { $0.votes >= 2 }.prefix(3)
            if !alternatives.isEmpty {
                Text("Or did you mean").font(.caption).foregroundStyle(.secondary).padding(.top, 4)
                ForEach(alternatives) { c in
                    Button(c.entry.displayName) {
                        onFinish(ScanResult(entry: c.entry, ndc: scan.ndc, lotNumber: scan.lotNumber, strength: scan.strength))
                        dismiss()
                    }
                    .font(.subheadline)
                }
            }

            Button {
                finish()
            } label: {
                Text(useLabel).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(scan.leader == nil && scan.ndc == nil)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.bar)
    }

    private var useLabel: String {
        guard let name = scan.leader?.displayName else { return "Use" }
        return scan.isStable ? "Use \(name)" : "Use \(name) anyway"
    }

    private func slot(_ label: String, value: String?, found: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: found ? "checkmark.circle.fill" : (value == nil ? "circle.dotted" : "circle"))
                .foregroundStyle(found ? Color.green : Color.secondary)
                .accessibilityHidden(true)
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value ?? "—")
                .font(.body.monospaced())
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value ?? "not found yet")\(found ? ", confirmed" : "")")
    }

    private func finish() {
        onFinish(ScanResult(entry: scan.leader, ndc: scan.ndc, lotNumber: scan.lotNumber, strength: scan.strength))
        dismiss()
    }
}

/// VisionKit's live text + barcode scanner, feeding every frame's results
/// into the accumulator.
private struct LabelScanner: UIViewControllerRepresentable {
    let scan: ScanAccumulator

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [
                .text(),
                .barcode(symbologies: [.upce, .ean8, .ean13, .code128, .dataMatrix, .qr]),
            ],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        context.coordinator.start(scanner)
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        coordinator.stop(scanner)
    }

    func makeCoordinator() -> Coordinator { Coordinator(scan: scan) }

    @MainActor
    final class Coordinator {
        let scan: ScanAccumulator
        private var task: Task<Void, Never>?

        init(scan: ScanAccumulator) { self.scan = scan }

        func start(_ scanner: DataScannerViewController) {
            try? scanner.startScanning()
            task = Task { @MainActor [scan] in
                for await items in scanner.recognizedItems {
                    var lines: [String] = []
                    var codes: [String] = []
                    for item in items {
                        switch item {
                        case .text(let t): lines.append(t.transcript)
                        case .barcode(let b): if let s = b.payloadStringValue { codes.append(s) }
                        @unknown default: break
                        }
                    }
                    scan.ingest(textLines: lines, barcodes: codes)
                }
            }
        }

        func stop(_ scanner: DataScannerViewController) {
            task?.cancel()
            scanner.stopScanning()
        }
    }
}
