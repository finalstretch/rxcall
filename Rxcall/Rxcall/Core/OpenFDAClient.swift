import Foundation

/// Talks directly to api.fda.gov from the device. No proxy, no key.
/// Rate limits without a key are 240 requests/minute and 1,000/day per IP —
/// far more than one phone checking its own list will use.
struct OpenFDAClient {
    private let base = URL(string: "https://api.fda.gov/drug/enforcement.json")!
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Ongoing recalls whose product description mentions `name`, newest first.
    /// Text search deliberately — see docs/openfda-notes.md, finding 2.
    func ongoingRecalls(mentioning name: String) async throws -> [Recall] {
        let term = name.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\"", with: "")
        guard !term.isEmpty else { return [] }

        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "search", value: "product_description:\"\(term)\" AND status:Ongoing"),
            URLQueryItem(name: "sort", value: "recall_initiation_date:desc"),
            URLQueryItem(name: "limit", value: "100"),
        ]
        let (data, response) = try await session.data(from: components.url!)

        // openFDA answers a search with no hits with HTTP 404, not an empty list.
        if let http = response as? HTTPURLResponse, http.statusCode == 404 {
            return []
        }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try decoder.decode(Envelope.self, from: data).results
    }

    /// Ongoing recalls mentioning any of the medication's names, de-duplicated.
    func ongoingRecalls(for medication: Medication) async throws -> [Recall] {
        var seen = Set<String>()
        var all: [Recall] = []
        for term in medication.searchTerms {
            for recall in try await ongoingRecalls(mentioning: term) where seen.insert(recall.id).inserted {
                all.append(recall)
            }
        }
        return all
    }

    private struct Envelope: Decodable {
        let results: [Recall]
    }
}

/// Matches recalls against a medication and grades the confidence.
enum RecallMatcher {
    static func matches(for medication: Medication, in recalls: [Recall]) -> [RecallMatch] {
        let userNDCs = medication.ndc.map(candidateNDCs) ?? []
        return recalls.map { recall in
            let confidence: MatchConfidence
            if !userNDCs.isEmpty, !recall.allNDCs.isDisjoint(with: userNDCs) {
                confidence = .ndc
            } else {
                confidence = .name
            }
            return RecallMatch(recall: recall, confidence: confidence)
        }
        .sorted { ($0.confidence, $0.recall.recallInitiationDate) > ($1.confidence, $1.recall.recallInitiationDate) }
    }

    /// Labeler-product forms an entered NDC could correspond to, for comparing
    /// against openFDA's hyphenated `product_ndc`.
    ///
    /// Typed with hyphens ("68462-521-90") the split is known. Read from a
    /// barcode it's ten bare digits, and the FDA allows three layouts
    /// (4-4-2, 5-3-2, 5-4-1), so all three splits are tried.
    static func candidateNDCs(_ raw: String) -> Set<String> {
        let parts = raw.split(separator: "-").map(String.init)
        if parts.count >= 2 { return ["\(parts[0])-\(parts[1])"] }
        let d = raw.filter(\.isNumber)
        guard d.count == 10 else { return [raw] }
        return [
            "\(d.prefix(4))-\(d.dropFirst(4).prefix(4))",
            "\(d.prefix(5))-\(d.dropFirst(5).prefix(3))",
            "\(d.prefix(5))-\(d.dropFirst(5).prefix(4))",
        ]
    }
}
