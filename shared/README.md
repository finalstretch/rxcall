# shared/

What both platforms must agree on. Nothing in here is Swift or Kotlin.

```
shared/
├── data/          the content the apps ship
│   ├── drug-index.json   built by tools/build_drug_index.py
│   └── glossary.json     exported by tools/record_fixtures.sh
├── fixtures/      the behavioural contract
│   ├── matching/  medication + recorded recalls → expected ordered matches
│   ├── scanning/  OCR frame sequences → expected ScanResult
│   └── glossary/  recall reason text → expected plain-language output
└── PARITY.md      what Android has and hasn't caught up on
```

## Why fixtures and not a specification

A written specification drifts. Someone changes the matcher, forgets the
document, and nothing anywhere complains — the two apps quietly disagree and
the first person to find out is a user holding a recalled bottle.

A fixture can't drift, because both platforms run it as a test. If the Kotlin
`ScanAccumulator` scores a brand hit 3 instead of 4, `white-cream-needs-two-frames`
fails. Nobody has to remember the thresholds; the fixture remembers them.

## Where the expected values come from

They are **recorded from the iOS implementation**, never written by hand:

```
tools/record_fixtures.sh
```

builds the app with a DEBUG-only recorder, runs the real `RecallMatcher`,
`ScanAccumulator` and `RecallGlossary` over every fixture's `input`, and writes
what they actually produced into `expected`. So the contract is what the
shipped app does, not what anyone believes it does — including a bug, if there
is one. A fixture that looks wrong means iOS is wrong, and that is the useful
thing about it.

Recorded openFDA responses are checked in, so tests never touch the network
and don't break when the FDA publishes something new.

## Changing behaviour

Change the fixture first, then both implementations. A PR that changes an
`expected` value should say why in its description — that value is the record
of a decision, and `scanning/white-cream-needs-two-frames` in particular
encodes a real misread found on a real tube.
