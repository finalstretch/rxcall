# Decisions

One dated paragraph per product or architecture decision. Newest at the bottom.

---

**2026-09-11 — Rx-call scope: drug recalls only, via openFDA.** The broader idea was a unified recall matcher across openFDA (drugs), CPSC (consumer products), and USDA FSIS (meat/poultry). We're starting with drugs only. One data source is shippable by one developer in a few months; three means three ingestion layers and three matching problems before anything reaches a user. openFDA is also the best-behaved of the three: JSON, no API key, structured `classification`, `code_info` (lot numbers), and an `openfda` block with brand/generic names and NDC codes on many records. CPSC and FSIS can be added later behind the same "your list vs. the feed" model. — Reeha Tabassum (author), Ruhi Tabassum (reviewer)

**2026-09-11 — No openFDA API key.** openFDA works without a key at 240 requests/minute and 1,000/day per IP. That's more than one phone will ever use, and a key would be a secret in a repo that's going public. If we ever hit the limit, the fix is fewer/larger queries, not a key. — Reeha Tabassum (author), Ruhi Tabassum (reviewer)

**2026-09-11 — Matching is presented as "possible match," never "recalled," unless the NDC matches.** Many enforcement records lack the `openfda` block, so matching often falls back to text search over `product_description`. Text matches can be wrong in both directions. The UI says what kind of match it is and always shows the lot numbers so the user can compare with their bottle. — Reeha Tabassum (author), Ruhi Tabassum (reviewer)
