import SwiftUI
import VisionKit

/// What a scan hands back to the add form.
struct ScanResult {
    var entry: DrugEntry?
    var ndc: String?
    var lotNumber: String?
}

/// Live camera scan of a medication label. Everything the camera sees is
/// processed on the phone by VisionKit and matched against the bundled drug
/// index; no image or text leaves the device.
struct ScanView: View {
    let onFinish: (ScanResult) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var scan = ScanAccumulator()

    private var canScan: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if canScan {
                    LabelScanner(scan: scan)
                        .ignoresSafeArea(edges: .horizontal)
                } else {
                    ContentUnavailableView("Scanning needs a camera",
                                           systemImage: "camera",
                                           description: Text("This device can't scan labels. You can still type the name."))
                }
                findings
            }
            .navigationTitle("Scan the label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use") { finish() }
                        .disabled(scan.leader == nil && scan.ndc == nil)
                }
            }
        }
    }

    private var findings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(prompt)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            slot("Medication", value: scan.leader?.displayName, found: scan.isStable)
            slot("NDC", value: scan.ndc, found: scan.ndc != nil)
            slot("Lot number", value: scan.lotNumber, found: scan.lotNumber != nil)

            // Runners-up with real support, so a wrong guess is one tap from fixed.
            let alternatives = scan.candidates.dropFirst().filter { $0.votes >= 2 }.prefix(3)
            if !alternatives.isEmpty {
                Text("Or did you mean").font(.caption).foregroundStyle(.secondary).padding(.top, 4)
                ForEach(alternatives) { c in
                    Button(c.entry.displayName) {
                        onFinish(ScanResult(entry: c.entry, ndc: scan.ndc, lotNumber: scan.lotNumber))
                        dismiss()
                    }
                    .font(.subheadline)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.bar)
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

    private var prompt: String {
        if !canScan { return "" }
        if scan.leader == nil { return "Point the camera at the label and slowly turn the bottle." }
        if !scan.isStable { return "Keep turning — making sure of the name." }
        if scan.ndc == nil || scan.lotNumber == nil { return "Got it. Keep turning for the NDC and lot number, or tap Use." }
        return "All set — tap Use."
    }

    private func finish() {
        onFinish(ScanResult(entry: scan.leader, ndc: scan.ndc, lotNumber: scan.lotNumber))
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
