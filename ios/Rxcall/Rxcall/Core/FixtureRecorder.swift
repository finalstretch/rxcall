#if DEBUG
import Foundation

/// Records the expected half of `shared/fixtures/` by running the real
/// implementations over the inputs. Android asserts against what this writes,
/// so the contract is whatever the shipped iOS code actually does — not what
/// anyone believes it does.
///
/// DEBUG only, so none of this is in a release build. Run it with
/// `tools/record_fixtures.sh`; it reads and rewrites fixture files copied into
/// the app's Documents directory, because a simulator app can't reach the
/// repo directly.
enum FixtureRecorder {
    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("-record-fixtures")
    }

    /// Writes `expected` into every fixture, then `done.txt` so the script
    /// driving this knows it finished rather than guessing from a timeout.
    @MainActor
    static func run() {
        let docs = URL.documentsDirectory
        let root = docs.appending(path: "fixtures")
        var report: [String] = []

        let files = (FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "json" } ?? []).sorted { $0.path < $1.path }

        for file in files {
            do {
                guard var fixture = try JSONSerialization.jsonObject(
                        with: Data(contentsOf: file)) as? [String: Any],
                      let kind = fixture["kind"] as? String,
                      let input = fixture["input"] as? [String: Any]
                else { report.append("SKIP \(file.lastPathComponent)"); continue }

                switch kind {
                case "matching": fixture["expected"] = try matching(input)
                case "scanning": fixture["expected"] = scanning(input)
                case "glossary": fixture["expected"] = glossary(input)
                default: report.append("SKIP unknown kind \(kind)"); continue
                }

                let out = try JSONSerialization.data(
                    withJSONObject: fixture,
                    options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
                try (out + Data("\n".utf8)).write(to: file)
                report.append("OK   \(file.lastPathComponent)")
            } catch {
                report.append("FAIL \(file.lastPathComponent): \(error)")
            }
        }

        // The glossary table itself, so Android can read it as data rather
        // than transcribing it out of Swift by hand.
        let table = RecallGlossary.allEntries.map {
            ["keywords": $0.keywords, "explanation": $0.explanation] as [String: Any]
        }
        let guidance = ["Class I", "Class II", "Class III", "Unclassified"]
            .reduce(into: [String: String]()) { $0[$1] = RecallGlossary.whatToDo(for: $1) }
        if let data = try? JSONSerialization.data(
            withJSONObject: ["entries": table, "whatToDo": guidance],
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) {
            try? (data + Data("\n".utf8)).write(to: docs.appending(path: "glossary.json"))
            report.append("OK   glossary.json")
        }

        try? report.joined(separator: "\n").write(to: docs.appending(path: "done.txt"),
                                                  atomically: true, encoding: .utf8)
    }

    // MARK: - Per kind

    private static func matching(_ input: [String: Any]) throws -> [[String: Any]] {
        let med = input["medication"] as? [String: Any] ?? [:]
        let medication = Medication(
            name: med["name"] as? String ?? "",
            genericName: med["genericName"] as? String,
            ndc: med["ndc"] as? String,
            strength: med["strength"] as? String)
        let recallData = try JSONSerialization.data(withJSONObject: input["recalls"] ?? [])
        let recalls = try JSONDecoder().decode([Recall].self, from: recallData)
        return RecallMatcher.matches(for: medication, in: recalls).map {
            ["recallNumber": $0.recall.recallNumber,
             "confidence": $0.confidence == .ndc ? "ndc" : "name",
             "mentionsStrength": $0.mentionsStrength]
        }
    }

    private static func scanning(_ input: [String: Any]) -> [String: Any] {
        let frames = input["frames"] as? [[String: Any]] ?? []
        let accumulator = ScanAccumulator()
        var stableAtFrame: Int?
        for (i, frame) in frames.enumerated() {
            accumulator.ingest(textLines: frame["text"] as? [String] ?? [],
                               barcodes: frame["barcodes"] as? [String] ?? [])
            if stableAtFrame == nil, accumulator.isStable { stableAtFrame = i + 1 }
            // ingest() ignores frames arriving within 250 ms of the last one,
            // exactly as it does on a live camera. Replay has to respect that
            // or every frame after the first is dropped.
            Thread.sleep(forTimeInterval: 0.3)
        }
        return [
            "stableAtFrame": stableAtFrame as Any,
            "framesSeen": accumulator.framesSeen,
            "leader": accumulator.leader?.displayName as Any,
            "ndc": accumulator.ndc as Any,
            "lotNumber": accumulator.lotNumber as Any,
            "strength": accumulator.strength as Any,
            "candidates": accumulator.candidates.prefix(4).map {
                ["name": $0.entry.displayName, "votes": $0.votes, "frames": $0.frames]
            },
        ]
    }

    private static func glossary(_ input: [String: Any]) -> [String: Any] {
        let reasons = input["reasons"] as? [String] ?? []
        let classifications = input["classifications"] as? [String] ?? []
        return [
            "explanations": reasons.reduce(into: [String: Any]()) {
                $0[$1] = RecallGlossary.explanation(for: $1) as Any
            },
            "whatToDo": classifications.reduce(into: [String: String]()) {
                $0[$1] = RecallGlossary.whatToDo(for: $1)
            },
        ]
    }
}
#endif
