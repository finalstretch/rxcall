# openFDA drug enforcement API — what the data actually looks like

Notes from the exploration scripts in `tools/`, run 2026-09-11. Re-run them if this
seems stale; the numbers below are a snapshot.

Endpoint: `https://api.fda.gov/drug/enforcement.json` · no key · 240 req/min, 1,000/day per IP.
Docs: https://open.fda.gov/apis/drug/enforcement/

## Scale

| | |
|---|---|
| All drug enforcement records | 17,938 |
| `status:Ongoing` | 2,699 (3.9 MB of JSON) |
| New recalls per year | ~500–1,400 (2026 YTD: 498) |
| Ongoing recalls mentioning "metformin" | 23 |
| Ongoing recalls mentioning "lisinopril" | 2 |

Small enough that the app queries per medication rather than syncing the dataset.

## Fields that matter

| Field | Notes |
|---|---|
| `product_description` | Free text. Almost always contains drug name, strength, package size, firm, and usually the NDC. |
| `reason_for_recall` | Free text. Ranges from "CGMP Deviations" (paperwork) to "Label mixup: contains Dilaudid instead of morphine" (urgent). |
| `classification` | `Class I` / `Class II` / `Class III` / `Not Yet Classified`. Ongoing: 225 / 2,310 / 163 / 1. |
| `status` | `Ongoing` / `Completed` / `Terminated`. Filter on `Ongoing`. |
| `code_info` | Lot numbers and expiry. **Unstructured** — see below. |
| `recall_initiation_date`, `report_date` | `YYYYMMDD` strings. |
| `recalling_firm` | Company name. No contact info in the record. |
| `distribution_pattern` | Free text; ~90% some spelling of "Nationwide". Occasionally a state list (`OH`). |
| `product_quantity` | Free text, sometimes `N/A`. |
| `openfda.brand_name`, `openfda.generic_name`, `openfda.product_ndc` | Clean, structured — **but present on only 40% of ongoing records.** |

## Finding 1: structured names are missing on most records; the NDC usually isn't

Of 2,699 ongoing records, 1,627 (60%) have no `openfda` block. But 668 of those have an
NDC written in `product_description` (`NDC 68462-521-90`, `NDC: 00597-0300-45`). Regex
`\b\d{4,5}-\d{3,4}-\d{1,2}\b` recovers it, bringing NDC coverage to **64%** of ongoing records.

The remaining 36% are mostly compounding pharmacies, hand sanitizers, and store-brand OTC
products — largely outside the "prescription on my counter" use case.

## Finding 2: text matching is not as noisy as feared, and catches things structured matching misses

100 records matching `product_description:"lisinopril"` and having an `openfda` block:
**0** whose `openfda.generic_name` lacked lisinopril.

Text matching also finds combination products. The newest ongoing metformin recall
(D-0657-2026) is Synjardy XR (empagliflozin + metformin) with no `openfda` block. A
metformin user wants to know; only text search finds it.

**Strategy:** match by text, then use NDC (if the user has entered one from their bottle)
to raise confidence. Not "NDC or nothing."

## Finding 3: lot numbers are unstructured — show, don't parse

Observed `code_info` values:

```
1931102AL
Lot: C03065F
Lot #  17231956, exp. date Aug-25
Lot# (a) Lots L300255, L300262, Exp Date 07/31/2025;  (b)L300263, Exp Date 08/31/2025
All Lots
```

Display verbatim so the person can compare to the bottle. Detect "All lots" (case-insensitive)
as the one case where there's nothing to compare — that recall applies regardless.

## Finding 4: ~27% of ongoing recalls are hospital products

Injectables, IV bags, prefilled syringes. Two of the three most recent Class I recalls were
(Lactated Ringer's, morphine syringes). Detect via `injection|vial|infusion|bag|syringe|IV\b`
in the description and label as a hospital/clinic product rather than something the user has at home.

## Finding 5: per-drug counts, text vs. structured

| drug | text, all | text, ongoing | `openfda`, all | `openfda`, ongoing |
|---|---|---|---|---|
| metformin | 91 | 23 | 43 | 7 |
| lisinopril | 41 | 2 | 15 | 1 |
| atorvastatin | 67 | 8 | 48 | 6 |
| levothyroxine | 185 | 61 | 120 | 61 |
| amlodipine | 95 | 32 | 40 | 15 |
| losartan | 117 | 37 | 36 | 4 |
| ibuprofen | 69 | 16 | 32 | 7 |
| acetaminophen | 240 | 24 | 57 | 14 |

Structured search alone would miss 2–9× the recalls that text search finds.

## Implications for the app

1. **Fetch:** one request per medication — `product_description:"<name>" AND status:Ongoing`, sorted `recall_initiation_date:desc`. A few KB each.
2. **Match tiers:** NDC match (user-entered from bottle) → name match → always show `code_info` verbatim. Wording: "Recalled — matches your bottle" vs. "Possible match — check your lot number."
3. **Plain-language layer:** classification explainer; glossary for common `reason_for_recall` phrases; hospital-product flag; "All lots" detector; date formatting.
4. **Medication entry:** `openfda.generic_name` is unreliable on *enforcement* records, so use `drug/ndc.json` or `drug/label.json` for name autocomplete when adding a medication — those are complete.
5. **Contact:** the record has the firm name but no phone/URL. Handoff is "contact your pharmacist" plus the FDA recall page, not a direct line to the firm.
