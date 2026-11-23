# iOS — Rxcall

Swift, SwiftUI, SwiftData. Shipped on the App Store; **this is the primary
implementation**, and Android follows it.

Because it's shipped, changes here carry more weight than the same change on
Android. Verify on the simulator before saying something works, and check any
view that gained text at the largest accessibility text size:

```
xcrun simctl ui <device> content_size accessibility-extra-extra-extra-large
```

## Layout

- `Rxcall/Rxcall/Core/` — models, API clients, matching, scanning, glossary.
  **This is what Android has to match.** A change here needs a parity decision;
  see `shared/PARITY.md`.
- `Rxcall/Rxcall/Views/` — screens. Free to be as iOS-idiomatic as it likes;
  Android should not imitate it.
- `Rxcall/Rxcall/Resources/drug-index.json` — a synced copy. The canonical file
  is `shared/data/drug-index.json`; run `tools/sync_shared.py` after rebuilding
  the index, and `--check` to verify they still agree.

## Conventions worth keeping

- Register `navigationDestination` at the root of the stack, not inside pushed
  screens — declaring them deeper resolves unreliably.
- Build a `NavigationPath` whole and assign it once. Mutating it several times
  in one update makes NavigationStack fault.
- DEBUG-only launch arguments (`-demo`, `-screen`, `-tutorial`, `-settings`,
  `-notification`, `-record-fixtures`) drive the app from the command line for
  screenshots and recording. They compile out of release builds; keep it that
  way.
- The simulator's preferences daemon caches `UserDefaults` across
  uninstall/reinstall. `simctl erase` is the only reliable way to test
  first-run behaviour — a reinstall is not.

## Before changing Core

Run `tools/record_fixtures.sh` and look at the diff. If an `expected` value
moved, you changed behaviour Android is pinned to — say so in the PR, and say
whether it was deliberate.
