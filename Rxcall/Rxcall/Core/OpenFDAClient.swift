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

    private struct Envelope: Decodable {
        let results: [Recall]
    }
}

/// Matches recalls against a medication and grades the confidence.
enum RecallMatcher {
    static func matches(for medication: Medication, in recalls: [Recall]) -> [RecallMatch] {
        let userNDC = medication.ndc.map(normalizeNDC)
        return recalls.map { recall in
            let confidence: MatchConfidence
            if let userNDC, recall.allNDCs.contains(userNDC) {
                confidence = .ndc
            } else {
                confidence = .name
            }
            return RecallMatch(recall: recall, confidence: confidence)
        }
        .sorted { ($0.confidence, $0.recall.recallInitiationDate) > ($1.confidence, $1.recall.recallInitiationDate) }
    }

    /// Reduces a user-entered NDC (any of the common 10- or 11-digit layouts,
    /// with or without a package segment) to labeler-product form.
    static func normalizeNDC(_ raw: String) -> String {
        let parts = raw.split(separator: "-").map(String.init)
        guard parts.count >= 2 else { return raw }
        return "\(parts[0])-\(parts[1])"
    }
}
