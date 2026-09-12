# Rx-call

**An iOS app that watches the FDA's drug recall feed for the medications you actually take — and tells you, in plain language, whether the bottle on your counter is affected.**

Part of [The Final Stretch Project](https://finalstretch.org), a free, open-source project that carries public data the rest of the way to the people it's about.

---

## The problem

The FDA publishes every drug recall in the United States through a free, open API. Each record says exactly which product, which lot numbers, and why.

But it's written for distributors and pharmacies:

```
Product: Metformin Hydrochloride Extended-Release Tablets, USP 500 mg,
100-count bottles, NDC 12345-678-90
Lot: ABC1234, ABC1235, Exp 03/2027
Reason: N-Nitrosodimethylamine (NDMA) impurity above the acceptable
daily intake limit
Classification: Class II
```

A person taking metformin doesn't read the FDA's weekly enforcement report. They find out from a news story weeks later, if at all — and then can't tell whether *their* bottle is the recalled one.

Rx-call closes that gap. You keep a list of what you take on your phone; the app checks it against the recall feed and shows you only what affects you, with the lot numbers to compare against your bottle and what to do next.

## How it works

**No server, no account, no data leaving the device.**

| Step | What it does |
|---|---|
| **1 — Your list** | Add medications by name. The list is stored only on your phone (SwiftData). |
| **2 — Check** | Your phone queries the openFDA drug enforcement API directly and matches recalls against your list by brand name, generic name, and NDC. |
| **3 — Explain** | Each match is shown in plain language: what was recalled, why, how serious the FDA considers it, the lot numbers, and who to contact. |

The medication list never leaves the device. Queries go straight from the phone to `api.fda.gov` — there is no intermediary that could log them.

## Design rules

1. **Never tell someone to stop taking a medication.** Show the recall, show the lot numbers, and hand off to their pharmacist or the recalling firm's contact line.
2. **Be honest about uncertainty.** Recall records don't always name drugs cleanly. When a match is by text rather than by NDC, say "possible match — check your lot number," not "recalled."
3. **Verbatim source text is always one tap away.** The plain-language version is a navigation aid over the FDA's record, never a replacement.
4. **Health data never leaves the device.** No account, no server, no analytics.
5. **Free, no ads, no interested funding.** Nobody with a stake in what you're shown pays for this app.

## Data source

[openFDA drug enforcement API](https://open.fda.gov/apis/drug/enforcement/) — `https://api.fda.gov/drug/enforcement.json`. No key required.

## Status

Early development. Not yet on the App Store.

## Not medical advice

Rx-call surfaces public recall information. It does not diagnose, recommend treatment, or determine whether you should stop or change a medication. Talk to your pharmacist or doctor.

## License

[Apache-2.0](LICENSE). See [CONTRIBUTING.md](CONTRIBUTING.md) to get involved.
