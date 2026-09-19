import Foundation

/// Collects what the camera reads off a label over many frames and votes on
/// what the medication, NDC, and lot number are. A curved label is only ever
/// partly readable in one frame, and OCR garbles a word one frame and gets it
/// right the next, so nothing is trusted from a single read.
@Observable
final class ScanAccumulator {
    struct Candidate: Identifiable {
        let entry: DrugEntry
        var votes: Int
        var id: String { entry.id }
    }

    private(set) var candidates: [Candidate] = []
    private(set) var ndc: String?
    private(set) var lotNumber: String?
    private(set) var framesSeen = 0
    /// When the camera last read a line it hadn't seen before. Goes quiet when
    /// the person has stopped turning the bottle or is showing the same side.
    private(set) var lastNewReadAt: Date?
    private var seenLines = Set<String>()

    private var drugVotes: [String: (entry: DrugEntry, votes: Int)] = [:]
    private var ndcVotes: [String: Int] = [:]
    private var lotVotes: [String: Int] = [:]
    private var lastProcessed = Date.distantPast
    private let index: DrugIndex

    /// Votes the leading drug needs, and its lead over the runner-up, before
    /// we call it found. Tune these on real bottles.
    private let stableVotes = 3
    private let stableLead = 2

    init(index: DrugIndex = .shared) {
        self.index = index
    }

    var leader: DrugEntry? { candidates.first?.entry }

    /// Something's still missing and nothing new has been read for a while —
    /// time to suggest a different side of the bottle.
    var isStalled: Bool {
        guard let last = lastNewReadAt, !(isStable && ndc != nil && lotNumber != nil) else { return false }
        return Date().timeIntervalSince(last) > 2.5
    }

    /// True once one drug has clearly pulled ahead.
    var isStable: Bool {
        guard let top = candidates.first else { return false }
        let second = candidates.dropFirst().first?.votes ?? 0
        return top.votes >= stableVotes && top.votes - second >= stableLead
    }

    /// Feed one frame's worth of recognized text lines and barcode payloads.
    /// Frames arriving faster than a few per second are skipped; matching
    /// against the whole index per frame isn't free.
    func ingest(textLines: [String], barcodes: [String]) {
        let now = Date()
        guard now.timeIntervalSince(lastProcessed) > 0.25 else { return }
        lastProcessed = now
        framesSeen += 1

        let text = textLines.joined(separator: "\n")
        for line in textLines where line.count >= 4 && seenLines.insert(line).inserted {
            lastNewReadAt = now
        }

        // A brand name seen on the label counts for 4, an ingredient for 3, and a
        // long word that's the start of a drug name (the rest cut off by the
        // label's curve) for 1.
        for entry in index.matches(inText: text).prefix(5) {
            vote(entry, weight: entry.brand == nil ? 3 : 4)
        }
        for word in text.split(whereSeparator: { !$0.isLetter }) where word.count >= 6 {
            for entry in index.prefixMatches(for: String(word)) {
                vote(entry, weight: 1)
            }
        }

        for code in Self.ndcs(in: text) { ndcVotes[code, default: 0] += 1 }
        for code in barcodes.compactMap(Self.ndc(fromBarcode:)) { ndcVotes[code, default: 0] += 3 }
        for lot in Self.lots(in: text) { lotVotes[lot, default: 0] += 1 }

        candidates = drugVotes.values
            .map { Candidate(entry: $0.entry, votes: $0.votes) }
            .sorted { ($0.votes, -$0.entry.displayName.count) > ($1.votes, -$1.entry.displayName.count) }
        ndc = ndcVotes.max { $0.value < $1.value }?.key
        lotNumber = lotVotes.max { $0.value < $1.value }?.key
    }

    private func vote(_ entry: DrugEntry, weight: Int) {
        drugVotes[entry.id, default: (entry, 0)].votes += weight
    }

    // MARK: - Pulling codes out of text

    /// NDCs written on a label: 4-4-2, 5-3-2, or 5-4-1 with hyphens.
    static func ndcs(in text: String) -> [String] {
        matches(of: #"\b\d{4,5}-\d{3,4}-\d{1,2}\b"#, in: text)
    }

    /// "LOT 17232088", "Lot#: AC-016633", "LOT: J4H077".
    static func lots(in text: String) -> [String] {
        matches(of: #"(?i)\blot\s*(?:#|no\.?|number|:)?\s*:?\s*([A-Z0-9][A-Z0-9-]{3,})"#, in: text, group: 1)
    }

    /// The NDC inside a drug barcode, when the payload is one of the layouts
    /// that carry it: a UPC-A starting with 3 (OTC boxes), or a GS1 GTIN-14
    /// starting with 003 (prescription packaging). Returned as ten digits with
    /// no hyphens; where the labeler/product split falls is worked out later.
    static func ndc(fromBarcode payload: String) -> String? {
        let digits = payload.filter(\.isNumber)
        if digits.count == 12, digits.hasPrefix("3") {
            return String(digits.dropFirst().prefix(10))
        }
        if digits.count == 14, digits.hasPrefix("003") {
            return String(digits.dropFirst(3).prefix(10))
        }
        // GS1 application identifier form: (01)00312345678906...
        if let range = payload.range(of: #"\(01\)(\d{14})"#, options: .regularExpression) {
            return ndc(fromBarcode: String(payload[range].dropFirst(4)))
        }
        return nil
    }

    private static func matches(of pattern: String, in text: String, group: Int = 0) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { m in
            Range(m.range(at: group), in: text).map { String(text[$0]).uppercased() }
        }
    }
}
