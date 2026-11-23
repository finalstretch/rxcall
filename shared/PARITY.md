# Parity

iOS is primary. Android follows. This file is the ledger of where Android
stands, so a gap is visible rather than discovered by a user.

**The rule.** A change under `ios/Rxcall/Rxcall/Core/` lands with the Android
equivalent in the same PR, or adds a row here saying Android is behind and
why. Never silently.

**Core must be at parity. UI must not be.** A Compose app that imitates
SwiftUI is wrong on Android — it should use Material 3, the system back
gesture and the system share sheet. The fixtures pin behaviour; they say
nothing about pixels, deliberately.

## Core

| iOS | Android | Pinned by | Status |
|---|---|---|---|
| `Core/Models.swift` | — | `fixtures/matching/` | not started |
| `Core/OpenFDAClient.swift` (`RecallMatcher`) | — | `fixtures/matching/` | not started |
| `Core/DrugIndex.swift` | — | — | not started |
| `Core/ScanAccumulator.swift` | — | `fixtures/scanning/` | not started |
| `Core/RecallGlossary.swift` | `core/RecallGlossary.kt` | `fixtures/glossary/` | **done** — 3 tests green |
| `Core/MedlinePlus.swift` | — | — | not started |
| `Core/RecallStore.swift` | — | — | not started |
| `Core/BackgroundRefresh.swift` | — | — | not started — WorkManager, not a port |
| `Core/NotificationRouter.swift` | — | — | not started |

## Known divergences

**The glossary table lives in two places.** `RecallGlossary.swift` holds it
inline and is the source of truth; `shared/data/glossary.json` is *exported
from it* by `tools/record_fixtures.sh`, and Android reads the JSON. Two copies
is not the end state — iOS should read the JSON too — but that means editing a
shipped, approved app, so it waits for its own PR and its own review.
`fixtures/glossary/` catches any drift between them in the meantime.

**Background checks are not a port.** `BGAppRefreshTask` has no Android
equivalent worth imitating. WorkManager gives real scheduling guarantees where
iOS gives none, so Android's checks will be more reliable, not merely
equivalent. The behaviour that must match is *what counts as a new recall* —
that lives in `RecallMatcher` and is pinned by fixtures.

## Bugs the fixtures pin — do not reproduce these on Android

Expected values are recorded from the shipped iOS code, so a bug in iOS
becomes a bug written into the contract. When one is found, it gets recorded
here rather than quietly fixed in the fixture, because the fixture's job is to
describe what iOS does. Android should implement the **correct** behaviour and
the fixture should be re-recorded once iOS is fixed.

### `openfda.product_ndc` is never read (found 2026-11-22)

`Recall.OpenFDA` declares `brandName`, `genericName` and `productNdc` in
camelCase with no `CodingKeys`, and `OpenFDAClient` uses a plain `JSONDecoder`
with no key strategy. openFDA sends `brand_name`, `generic_name` and
`product_ndc`, so every one of those decodes as `nil`. `openfda` itself is
present, which is why nothing ever looked wrong.

The effect is on `Recall.allNDCs`, which unions the structured field with NDCs
parsed out of `product_description`. Only the text path works. So an NDC the
person entered matches **only when the recall spells it out in its description**,
and silently misses when it lives in the structured field — which is the
reliable one.

Two fixtures hold both halves:

| Fixture | NDC lives in | Recorded result |
|---|---|---|
| `matching/ndc-written-into-the-description` | `product_description` | `ndc` — correct |
| `matching/ndc-beats-everything` | `openfda.product_ndc` | `name` — **wrong** |

In the four alprazolam recalls those fixtures use, one of four carries its NDC
only in the structured field, and it's the current 2026 Xanax XR recall. The
cost is a "Recall matches your bottle" that shows up as a mere "possible
match", on the one signal the app treats as certain.

Fix is one line — `CodingKeys` on `OpenFDA`, or `convertFromSnakeCase` on the
decoder — but it changes matching behaviour in a shipped medical app, so it
wants its own PR and its own review rather than riding along with a repo
restructure.

## Open question — “Lack of Assurance of Sterility”

Not a bug, but worth a decision, and the glossary port is what surfaced it.

The table is first-hit-wins, and the entry keyed on `lack of assurance` sits
above the one keyed on `sterility`. So `Lack of Assurance of Sterility` gets:

> The manufacturer couldn't show that its process was properly controlled.
> Often a paperwork or process issue rather than a known problem with the
> product.

rather than:

> The product may be contaminated with bacteria, mold, or another
> microorganism.

**242 of 1,000 ongoing recalls sampled on 2026-11-22 carry that exact phrase** —
roughly a quarter of everything the app will ever show — and every one of them
is Class II.

There's a real argument for the current wording: *lack of assurance* of
sterility means the manufacturer can't demonstrate sterility, not that
contamination was found, so describing it as a process failure is accurate.
The part that gives pause is the tail — “often a paperwork issue rather than a
known problem with the product” — attached to a quarter of all recalls, some
of which follow media fills that did grow bacteria.

Options, for whoever picks this up: leave it, reorder so `sterility` wins, or
give the phrase its own entry that says the manufacturer couldn't demonstrate
sterility without implying paperwork. It changes wording in a shipped app, so
it wants its own PR either way, and the glossary fixture would have to be
re-recorded with it.

## Platform mapping

| iOS | Android |
|---|---|
| SwiftUI | Jetpack Compose |
| SwiftData | Room |
| `@AppStorage` | DataStore |
| VisionKit `DataScannerViewController` | CameraX + ML Kit Text Recognition |
| GS1 barcode payloads | ML Kit Barcode Scanning (AIs still parsed by us) |
| `BGAppRefreshTask` | WorkManager |
| `UNUserNotificationCenter` | `NotificationManager` + `POST_NOTIFICATIONS` |
| VoiceOver / Dynamic Type | TalkBack / `sp` units and font scale |
