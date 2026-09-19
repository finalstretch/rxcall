import Foundation

/// A short, plain-language description of a medication from MedlinePlus —
/// the National Library of Medicine's patient-facing drug pages. Two calls,
/// both to NLM, both carrying only the drug name: RxNorm turns the name into
/// an RxCUI, MedlinePlus Connect turns that into the page. Nothing about the
/// person is sent, same as the recall lookup.
struct DrugInfo: Equatable {
    let title: String
    let summary: String
    let url: URL
}

actor MedlinePlusClient {
    static let shared = MedlinePlusClient()
    private var cache: [String: DrugInfo?] = [:]

    /// Tries the medication's name, then its generic.
    func info(for medication: Medication) async -> DrugInfo? {
        for name in medication.searchTerms {
            if let cached = cache[name.lowercased()] { if let cached { return cached } else { continue } }
            let result = await lookup(name)
            cache[name.lowercased()] = result
            if let result { return result }
        }
        return nil
    }

    private func lookup(_ name: String) async -> DrugInfo? {
        guard let rxcui = await rxcui(for: name) else { return nil }
        var c = URLComponents(string: "https://connect.medlineplus.gov/service")!
        c.queryItems = [
            .init(name: "mainSearchCriteria.v.cs", value: "2.16.840.1.113883.6.88"),   // RxNorm
            .init(name: "mainSearchCriteria.v.c", value: rxcui),
            .init(name: "knowledgeResponseType", value: "application/json"),
        ]
        guard let (data, _) = try? await URLSession.shared.data(from: c.url!),
              let feed = try? JSONDecoder().decode(ConnectFeed.self, from: data),
              let entry = feed.feed.entry.first,
              let link = entry.link.first.flatMap({ URL(string: $0.href) })
        else { return nil }
        return DrugInfo(title: entry.title._value,
                        summary: Self.firstSentences(of: Self.stripHTML(entry.summary._value), count: 2),
                        url: link)
    }

    private func rxcui(for name: String) async -> String? {
        var c = URLComponents(string: "https://rxnav.nlm.nih.gov/REST/rxcui.json")!
        c.queryItems = [.init(name: "name", value: name), .init(name: "search", value: "2")]
        guard let (data, _) = try? await URLSession.shared.data(from: c.url!),
              let r = try? JSONDecoder().decode(RxcuiResponse.self, from: data)
        else { return nil }
        return r.idGroup.rxnormId?.first
    }

    private struct RxcuiResponse: Decodable {
        struct IdGroup: Decodable { let rxnormId: [String]? }
        let idGroup: IdGroup
    }
    private struct ConnectFeed: Decodable {
        struct Feed: Decodable { let entry: [Entry] }
        struct Entry: Decodable {
            struct Text: Decodable { let _value: String }
            struct Link: Decodable { let href: String }
            let title: Text
            let summary: Text
            let link: [Link]
        }
        let feed: Feed
    }

    private static func stripHTML(_ s: String) -> String {
        s.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    private static func firstSentences(of s: String, count: Int) -> String {
        var out: [String] = []
        s.enumerateSubstrings(in: s.startIndex..., options: .bySentences) { sub, _, _, stop in
            if let sub { out.append(sub.trimmingCharacters(in: .whitespaces)) }
            if out.count == count { stop = true }
        }
        return out.joined(separator: " ")
    }
}
