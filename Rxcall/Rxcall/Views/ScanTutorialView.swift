import SwiftUI

/// A looping, skippable animation showing how to scan a bottle: hold it up,
/// turn it slowly, keep turning for the other side, tap Use. Shown once before
/// the first scan; replayable from the scan screen.
struct ScanTutorialView: View {
    let onFinish: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0

    private let steps: [(title: String, detail: String)] = [
        ("Hold the bottle up", "Point the camera at the label, about a hand's width away."),
        ("Turn it slowly", "Rx-call reads the label as it comes into view and locks in the name."),
        ("Keep turning", "The NDC and lot number are usually on the other side, near the barcode."),
        ("Tap Use", "That's it. You can fix anything by hand on the next screen."),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        // The picture is an illustration, not text: it keeps its
                        // own size so large type doesn't swamp it.
                        BottleScene(step: step, reduceMotion: reduceMotion)
                            .frame(maxWidth: 340)
                            .aspectRatio(1, contentMode: .fit)
                            .dynamicTypeSize(.large)
                            .accessibilityHidden(true)

                        // Every caption is laid out (invisibly) so the block is
                        // always as tall as the longest one; otherwise the
                        // picture jumps up and down as the text changes length.
                        ZStack {
                            ForEach(steps.indices, id: \.self) { i in
                                caption(i)
                                    .opacity(i == step ? 1 : 0)
                                    .accessibilityHidden(i != step)
                            }
                        }
                        .padding(.horizontal, 24)
                        .animation(.easeInOut(duration: 0.4), value: step)
                        .accessibilityElement(children: .contain)
                        .accessibilityAddTraits(.updatesFrequently)

                        HStack(spacing: 8) {
                            ForEach(steps.indices, id: \.self) { i in
                                Capsule()
                                    .fill(i == step ? Color.accentColor : Color.secondary.opacity(0.3))
                                    .frame(width: i == step ? 22 : 8, height: 8)
                            }
                        }
                        .animation(.default, value: step)
                        .accessibilityHidden(true)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }

                Button {
                    finish()
                } label: {
                    Text(step == steps.count - 1 ? "Start scanning" : "Got it, start scanning")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }
            .navigationTitle("How to scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { finish() }
                }
            }
            .task { await loop() }
        }
    }

    private func caption(_ i: Int) -> some View {
        VStack(spacing: 8) {
            Text(steps[i].title)
                .font(.title2.bold())
            Text(steps[i].detail)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func loop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(step == 0 ? 2.2 : 3.2))
            withAnimation(.easeInOut(duration: 0.8)) { step = (step + 1) % steps.count }
        }
    }

    private func finish() {
        onFinish()
        dismiss()
    }
}

/// The picture: a camera viewfinder, a bottle whose label slides past as if
/// turning, and the three chips ticking as the name, NDC, and lot are read.
private struct BottleScene: View {
    let step: Int
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack {
                // viewfinder corners
                ViewfinderCorners()
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .padding(w * 0.04)
                    .opacity(step == 3 ? 0.35 : 1)

                Bottle(labelOffset: labelOffset, width: w * 0.42)
                    .frame(height: w * 0.62)
                    .offset(y: w * 0.03)

                // chips
                HStack(spacing: 8) {
                    chip("Name", done: step >= 1)
                    chip("NDC", done: step >= 2)
                    chip("Lot", done: step >= 2)
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, w * 0.10)

                // the Use button, lit on the last step
                Text("Use Metformin")
                    .font(.headline)
                    .padding(.horizontal, 22).padding(.vertical, 12)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
                    .scaleEffect(step == 3 ? 1.08 : 0.92)
                    .opacity(step == 3 ? 1 : 0.35)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, w * 0.08)

                // turning hint
                if step == 1 || step == 2 {
                    Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                        .font(.system(size: w * 0.09, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                        .padding(.trailing, w * 0.10)
                        .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 1.6), value: step)
        }
    }

    /// How far the label has slid: 0 shows the name, 1 shows the NDC/lot side.
    private var labelOffset: CGFloat {
        switch step {
        case 0: return -0.25
        case 1: return 0
        default: return 1
        }
    }

    private func chip(_ label: String, done: Bool) -> some View {
        Label(label, systemImage: done ? "checkmark.circle.fill" : "circle.dotted")
            .font(.caption.weight(.semibold))
            .foregroundStyle(done ? Color.green : Color.secondary)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(.regularMaterial, in: Capsule())
    }
}

/// A pill bottle. The label's content is offset horizontally inside a mask so
/// it looks like the bottle is turning; a gradient overlay gives it a curve.
private struct Bottle: View {
    /// 0 = drug name centred, 1 = NDC/lot centred.
    let labelOffset: CGFloat
    let width: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.systemGray))
                .frame(width: width * 0.8, height: width * 0.22)
            ZStack {
                RoundedRectangle(cornerRadius: width * 0.14)
                    .fill(Color.orange.opacity(0.28))
                label
                // cylinder shading
                RoundedRectangle(cornerRadius: width * 0.14)
                    .fill(LinearGradient(colors: [.black.opacity(0.22), .clear, .clear, .black.opacity(0.22)],
                                         startPoint: .leading, endPoint: .trailing))
                    .allowsHitTesting(false)
            }
            .frame(width: width)
        }
    }

    private var label: some View {
        let sideWidth = width * 0.86
        let span = sideWidth * 1.35          // one side plus the gap to the next
        return ZStack {
            Color.white
            HStack(spacing: sideWidth * 0.35) {
                labelSide(["RX #1234567", "METFORMIN", "HCL ER 500 MG", "TAKE 1 TABLET", "TWICE DAILY"], bold: 1)
                labelSide(["QTY 60  RF 2", "NDC 68462-", "0521-90", "LOT 17232088", "▌▌▌▌▌▌▌▌"], bold: nil)
            }
            .fixedSize()
            // The HStack is centred on the gap; shift by half a span so
            // offset 0 centres the name side and 1 centres the NDC side.
            .offset(x: span / 2 - labelOffset * span)
        }
        .frame(width: sideWidth)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func labelSide(_ lines: [String], bold: Int?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(lines.indices, id: \.self) { i in
                Text(lines[i])
                    .font(.system(size: width * 0.075, weight: i == bold ? .heavy : .regular, design: .monospaced))
                    .foregroundStyle(i == bold ? Color.black : Color.black.opacity(0.55))
            }
        }
        .frame(width: width * 0.86, alignment: .leading)
        .padding(.leading, width * 0.08)
    }
}

private struct ViewfinderCorners: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let l = min(r.width, r.height) * 0.12
        for (x, y, dx, dy) in [(r.minX, r.minY, 1.0, 1.0), (r.maxX, r.minY, -1.0, 1.0),
                               (r.minX, r.maxY, 1.0, -1.0), (r.maxX, r.maxY, -1.0, -1.0)] {
            p.move(to: CGPoint(x: x, y: y + dy * l))
            p.addLine(to: CGPoint(x: x, y: y))
            p.addLine(to: CGPoint(x: x + dx * l, y: y))
        }
        return p
    }
}

#Preview {
    ScanTutorialView {}
}
