import Foundation
import SwiftData

/// A medication the user takes. Stored on device only.
@Model
final class Medication {
    var name: String
    /// Generic name when the user picked a brand from the index, so recalls
    /// listed under the ingredient are found too.
    var genericName: String?
    /// NDC from the bottle, if the user entered one. Lets a recall be matched
    /// with certainty instead of by name.
    var ndc: String?
    /// Lot number from the bottle, if entered. Shown next to a recall's lot
    /// list so the user can compare; never parsed or matched automatically.
    var lotNumber: String?
    /// Strength as printed, e.g. "500 mg". Used to rank recalls that mention it.
    var strength: String?
    var addedAt: Date

    /// Last successful check and what it returned, so the app has something to
    /// show offline and can tell a new recall from one already seen.
    var lastCheckedAt: Date?
    var cachedRecallData: Data?
    var seenRecallNumbers: [String] = []

    /// Names worth searching the recall feed for.
    var searchTerms: [String] {
        guard let genericName, genericName.lowercased() != name.lowercased() else { return [name] }
        return [name, genericName]
    }

    init(name: String, genericName: String? = nil, ndc: String? = nil, lotNumber: String? = nil, strength: String? = nil) {
        self.name = name
        self.genericName = genericName
        self.ndc = ndc
        self.lotNumber = lotNumber
        self.strength = strength
        self.addedAt = .now
    }

    var cachedRecalls: [Recall] {
        get { cachedRecallData.flatMap { try? JSONDecoder().decode([Recall].self, from: $0) } ?? [] }
        set { cachedRecallData = try? JSONEncoder().encode(newValue) }
    }

    func hasSeen(_ recall: Recall) -> Bool { seenRecallNumbers.contains(recall.recallNumber) }

    func markSeen(_ recall: Recall) {
        if !hasSeen(recall) { seenRecallNumbers.append(recall.recallNumber) }
    }
}

/// One record from the openFDA drug enforcement API.
/// Field names mirror the API; see docs/openfda-notes.md for what they contain.
struct Recall: Codable, Identifiable, Hashable {
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

    struct OpenFDA: Codable, Hashable {
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

/// Navigation value for a recall opened from a medication's screen.
struct RecallRoute: Hashable {
    let match: RecallMatch
    let medication: Medication
}

struct RecallMatch: Identifiable, Hashable {
    let recall: Recall
    let confidence: MatchConfidence
    /// The recall text mentions the strength on the person's bottle.
    var mentionsStrength = false
    var id: String { recall.id }
}

extension Recall {
    /// Class I = 0 … unclassified = 3, for sorting most serious first.
    var severityRank: Int {
        switch classification {
        case "Class I": return 0
        case "Class II": return 1
        case "Class III": return 2
        default: return 3
        }
    }
}
