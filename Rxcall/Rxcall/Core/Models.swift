import Foundation
import SwiftData

/// A medication the user takes. Stored on device only.
@Model
final class Medication {
    var name: String
    /// NDC from the bottle, if the user entered one. Lets a recall be matched
    /// with certainty instead of by name.
    var ndc: String?
    /// Lot number from the bottle, if entered. Shown next to a recall's lot
    /// list so the user can compare; never parsed or matched automatically.
    var lotNumber: String?
    var addedAt: Date

    init(name: String, ndc: String? = nil, lotNumber: String? = nil) {
        self.name = name
        self.ndc = ndc
        self.lotNumber = lotNumber
        self.addedAt = .now
    }
}

/// One record from the openFDA drug enforcement API.
/// Field names mirror the API; see docs/openfda-notes.md for what they contain.
struct Recall: Decodable, Identifiable, Hashable {
    let recallNumber: String
    let status: String
    let classification: String
    let productDescription: String
    let reasonForRecall: String
    let codeInfo: String?
    let recallingFirm: String
    let recallInitiationDate: String
    let reportDate: String
    let distributionPattern: String?
    let openfda: OpenFDA?

    struct OpenFDA: Decodable, Hashable {
        let brandName: [String]?
        let genericName: [String]?
        let productNdc: [String]?
    }

    var id: String { recallNumber }

    enum CodingKeys: String, CodingKey {
        case recallNumber = "recall_number"
        case status, classification, openfda
        case productDescription = "product_description"
        case reasonForRecall = "reason_for_recall"
        case codeInfo = "code_info"
        case recallingFirm = "recalling_firm"
        case recallInitiationDate = "recall_initiation_date"
        case reportDate = "report_date"
        case distributionPattern = "distribution_pattern"
    }
}

// MARK: - Plain-language helpers

extension Recall {
    /// FDA classification, in words a person can act on.
    var classificationSummary: (title: String, detail: String) {
        switch classification {
        case "Class I":
            return ("Most serious",
                    "The FDA says using this product could cause serious health problems. Contact your pharmacist today.")
        case "Class II":
            return ("Moderate",
                    "The FDA says this product might cause a temporary or treatable problem, or that serious harm is unlikely.")
        case "Class III":
            return ("Least serious",
                    "The FDA says this product is unlikely to cause any health problem; it usually violates a labeling or manufacturing rule.")
        default:
            return ("Not yet classified", "The FDA hasn't decided how serious this recall is yet.")
        }
    }

    /// True when the recall covers every lot, so there's nothing on the bottle to compare.
    var appliesToAllLots: Bool {
        codeInfo?.range(of: "all lots", options: .caseInsensitive) != nil
    }

    /// Injectables, IV bags, and the like — products a person is unlikely to have at home.
    var looksLikeHospitalProduct: Bool {
        productDescription.range(of: #"injection|vial|infusion|\bbag\b|syringe|\bIV\b|intravenous"#,
                                 options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// Every NDC we can find: the structured field plus anything written in the description.
    /// Returned in product form (labeler-product, no package segment) for comparison.
    var allNDCs: Set<String> {
        var found = Set(openfda?.productNdc ?? [])
        let pattern = #"\b(\d{4,5}-\d{3,4})-\d{1,2}\b"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(productDescription.startIndex..., in: productDescription)
            for m in regex.matches(in: productDescription, range: range) {
                if let r = Range(m.range(at: 1), in: productDescription) {
                    found.insert(String(productDescription[r]))
                }
            }
        }
        return found
    }

    var initiationDate: Date? { Self.dateFormatter.date(from: recallInitiationDate) }
    var reportedDate: Date? { Self.dateFormatter.date(from: reportDate) }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        // Parsed in the local zone so the calendar day displays unchanged.
        return f
    }()
}

/// How confident we are that a recall applies to what the user has.
enum MatchConfidence: Comparable {
    /// The drug name appears in the recall. The user needs to check the lot number.
    case name
    /// The NDC the user entered from their bottle matches the recall.
    case ndc

    var label: String {
        switch self {
        case .ndc:  return "Matches your bottle"
        case .name: return "Possible match — check your lot number"
        }
    }
}

struct RecallMatch: Identifiable, Hashable {
    let recall: Recall
    let confidence: MatchConfidence
    var id: String { recall.id }
}
