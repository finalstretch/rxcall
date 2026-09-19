import SwiftUI

struct RecallDetailView: View {
    let match: RecallMatch
    var medication: Medication? = nil
    private var recall: Recall { match.recall }

    var body: some View {
        List {
            Section {
                Label(match.confidence.label,
                      systemImage: match.confidence == .ndc ? "exclamationmark.triangle.fill" : "questionmark.circle")
                    .font(.headline)
                if recall.looksLikeHospitalProduct {
                    Label("This looks like a hospital or clinic product (injection, IV, or vial), not something usually kept at home.",
                          systemImage: "cross.case")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section("How serious") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(recall.classificationSummary.title) (\(recall.classification))")
                        .font(.headline)
                    Text(recall.classificationSummary.detail)
                }
                .padding(.vertical, 2)
            }

            Section("Lot numbers") {
                if recall.appliesToAllLots {
                    Text("This recall covers every lot of the product, so there's nothing on the bottle to compare.")
                } else if let codes = recall.codeInfo, !codes.isEmpty {
                    Text(codes)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                    if let lot = medication?.lotNumber {
                        LabeledContent("Your bottle", value: lot)
                            .font(.body.monospaced())
                    }
                    Text("Compare these with the lot number printed on your bottle.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("The FDA record doesn't list lot numbers.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("What was recalled") {
                Text(recall.productDescription).textSelection(.enabled)
            }

            Section("Why") {
                if let plain = RecallGlossary.explanation(for: recall.reasonForRecall) {
                    Text(plain)
                    Text(recall.reasonForRecall)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                } else {
                    Text(recall.reasonForRecall).textSelection(.enabled)
                }
            }

            Section("What to do") {
                Text(RecallGlossary.whatToDo(for: recall.classification))
            }

            Section("Details") {
                LabeledContent("Recalling firm", value: recall.recallingFirm)
                if let d = recall.initiationDate {
                    LabeledContent("Recall started", value: d.formatted(date: .long, time: .omitted))
                }
                if let d = recall.reportedDate {
                    LabeledContent("Reported by FDA", value: d.formatted(date: .long, time: .omitted))
                }
                if let dist = recall.distributionPattern {
                    LabeledContent("Distributed", value: dist)
                }
                LabeledContent("Recall number", value: recall.recallNumber)
                LabeledContent("Status", value: recall.status)
                Link("View the FDA's recall record",
                     destination: URL(string: "https://www.accessdata.fda.gov/scripts/ires/index.cfm?Product=\(recall.recallNumber)")!)
            }
        }
        .navigationTitle("Recall")
        .navigationBarTitleDisplayMode(.inline)
    }
}
