import Foundation

/// Plain-language explanations for the phrases the FDA uses in
/// `reason_for_recall`. Matched by keyword; first hit wins, so more specific
/// entries come first. Nothing here is advice — it says what the words mean.
enum RecallGlossary {
    private static let entries: [(keywords: [String], explanation: String)] = [
        (["foreign tablet", "foreign capsule", "wrong tablet", "mixed product", "product mix"],
         "Some bottles may contain a different medication than the label says."),
        (["label mix", "labeling: label error", "mislabel", "incorrect label", "wrong label"],
         "The label on some packages is wrong — it may name a different drug, strength, or count than what's inside."),
        (["superpotent", "super potent", "high potency", "above specification"],
         "Some doses may be stronger than the label says."),
        (["subpotent", "sub potent", "low potency", "below specification", "failed assay"],
         "Some doses may be weaker than the label says, so they may not work as expected."),
        (["ndma", "nitrosamine", "nitroso", "ndea"],
         "Testing found a nitrosamine impurity above the level the FDA allows. The amount matters, and the FDA's page for this recall has the details."),
        (["impurities/degradation", "degradation", "impurity", "impurities"],
         "Testing found the medication breaking down, or an impurity, beyond the limit the FDA allows."),
        (["out of specification", "does not meet usp", "does not meet", "monograph", "failed specification"],
         "The product failed one of the quality tests it's required to pass."),
        (["imprint"],
         "The marking stamped on the tablets or capsules is wrong or missing, so they could be confused with another medication."),
        (["discolor", "crystalli", "precipitat"],
         "The product changed in appearance — discoloration or crystals — which can mean it's degrading."),
        (["defective container", "defective delivery", "leak", "seal", "cracked", "broken"],
         "The bottle, cartridge, or dispenser is faulty — it may leak, not seal properly, or not dispense correctly."),
        (["processing control", "lack of assurance", "lack of controls"],
         "The manufacturer couldn't show that its process was properly controlled. Often a paperwork or process issue rather than a known problem with the product."),
        (["fda's recommendation", "fda recommendation", "following fda"],
         "The manufacturer recalled it at the FDA's request. The FDA's page for this recall has the specific reason."),
        (["particulate", "glass", "particle", "visible matter"],
         "Small particles (like glass or fibers) were found in the product. Most serious for injections."),
        (["sterility", "non-sterile", "nonsterile", "microbial", "contamin", "mold", "bacteria", "burkholderia", "pseudomonas"],
         "The product may be contaminated with bacteria, mold, or another microorganism."),
        (["dissolution", "disintegration"],
         "Tablets may not dissolve properly, so the medication may be released too slowly or unevenly."),
        (["stability", "expir", "shelf life"],
         "The product may lose strength before its expiration date."),
        (["child-resistant", "child resistant", "packaging"],
         "The packaging doesn't meet a safety rule — often that the cap isn't child-resistant. The medicine itself is usually unaffected."),
        (["temperature excursion", "temperature", "cold chain"],
         "The product was exposed to temperatures outside its safe range during storage or shipping."),
        (["cgmp", "gmp", "good manufacturing", "manufacturing deviation", "deviation"],
         "The factory broke a manufacturing or record-keeping rule. This is often about paperwork or process, not a known problem with the product itself — but the FDA recalls it to be safe."),
        (["unapproved", "marketed without"],
         "The product was sold without FDA approval or outside what its approval allows."),
        (["tamper", "counterfeit"],
         "The product may be counterfeit or tampered with."),
    ]

    static func explanation(for reason: String) -> String? {
        let r = reason.lowercased()
        return entries.first { $0.keywords.contains { r.contains($0) } }?.explanation
    }

    /// What to do, by how serious the FDA says it is.
    static func whatToDo(for classification: String) -> String {
        switch classification {
        case "Class I":
            return "Don't take another dose until you've talked to your pharmacist — call today, or call the number on the recall. Don't throw the bottle away yet; they may want the lot number."
        case "Class II":
            return "Don't stop taking it on your own. Check the lot number against your bottle, and call or visit your pharmacist — they can replace it if it's affected."
        case "Class III":
            return "This kind of recall rarely affects your health. Mention it at your next refill, or ask your pharmacist if you're unsure."
        default:
            return "Don't stop taking a medication on your own. Take your bottle to your pharmacist, or call them, and ask whether it's part of this recall and what to do next."
        }
    }
}
