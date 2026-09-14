import Foundation

/// One marketed drug: a brand name (if it has one) and its generic name.
struct DrugEntry: Decodable, Identifiable, Hashable {
    let brand: String?
    let generic: String

    var id: String { "\(brand ?? "")|\(generic)" }

    /// What to show in a list: "Synjardy XR" or "Lisinopril".
    var displayName: String { brand ?? generic.capitalizedFirst }

    /// Generic shown under a brand; nothing under a plain generic.
    var subtitle: String? { brand == nil ? nil : generic }

    /// The name the user would recognise and the first active ingredient — the two
    /// terms worth searching the recall feed for.
    var searchTerms: [String] {
        var terms = [displayName]
        let ingredient = generic.split(whereSeparator: { $0 == "," || $0 == "/" })
            .first.map(String.init)?
            .components(separatedBy: " and ").first?
            .trimmingCharacters(in: .whitespaces) ?? generic
        if ingredient.lowercased() != displayName.lowercased() { terms.append(ingredient) }
        return terms
    }

    enum CodingKeys: String, CodingKey { case brand = "b", generic = "g" }
}

/// The bundled list of drug names, built by tools/build_drug_index.py from
/// openFDA's NDC dataset. Lives entirely on the device; used for autocomplete
/// and for recognising a drug name in text read off a label.
final class DrugIndex {
    static let shared = DrugIndex()

    let entries: [DrugEntry]
    private let searchable: [(entry: DrugEntry, brand: String, generic: String)]

    init(entries: [DrugEntry]) {
        self.entries = entries
        self.searchable = entries.map { ($0, $0.brand?.lowercased() ?? "", $0.generic.lowercased()) }
    }

    private convenience init() {
        // Missing or unreadable index just means no suggestions; typing still works.
        let entries = Bundle.main.url(forResource: "drug-index", withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONDecoder().decode([DrugEntry].self, from: $0) } ?? []
        self.init(entries: entries)
    }

    /// Autocomplete. Prefix matches on the name first (brand, or the generic when
    /// there's no brand), then on a brand's generic, then any word, then anywhere
    /// in the name; shorter names first within a tier.
    func suggestions(for query: String, limit: Int = 8) -> [DrugEntry] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard q.count >= 2 else { return [] }
        var scored: [(Int, Int, DrugEntry)] = []
        for (entry, brand, generic) in searchable {
            let name = brand.isEmpty ? generic : brand
            let tier: Int
            if name.hasPrefix(q)                                         { tier = 0 }
            else if generic.hasPrefix(q)                                 { tier = 1 }
            else if (brand + " " + generic).contains(" " + q)            { tier = 2 }
            else if brand.contains(q) || generic.contains(q)             { tier = 3 }
            else { continue }
            scored.append((tier, entry.displayName.count, entry))
        }
        return scored.sorted { ($0.0, $0.1) < ($1.0, $1.1) }.prefix(limit).map(\.2)
    }

    /// Drug names that appear in a block of text (e.g. lines read off a bottle).
    /// Brand-name hits first, then ingredient hits; longer names first within
    /// each, since "Synjardy XR" beats "Synjardy" beats "metformin".
    func matches(inText text: String) -> [DrugEntry] {
        let haystack = " " + text.lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression) + " "
        func present(_ name: String) -> Bool {
            guard name.count >= 4 else { return false }
            let needle = " " + name.replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression) + " "
            return haystack.contains(needle)
        }
        var found: [(tier: Int, entry: DrugEntry)] = []
        var seenNames = Set<String>()
        for (entry, brand, _) in searchable {
            let tier: Int
            let ingredient = entry.searchTerms.last?.lowercased() ?? ""
            if present(brand) { tier = 0 }
            // Short ingredient names ("iron", "mouth" from a malformed record) match
            // ordinary label words too often to be worth surfacing on their own.
            else if ingredient.count >= 6, present(ingredient) { tier = 1 }
            else { continue }
            if seenNames.insert(entry.displayName.lowercased()).inserted {
                found.append((tier, entry))
            }
        }
        return found
            .sorted { ($0.tier, -$0.entry.displayName.count) < ($1.tier, -$1.entry.displayName.count) }
            .map(\.entry)
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
