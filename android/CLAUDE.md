# Android — Rxcall

Kotlin, Jetpack Compose, Room. **Not scaffolded yet** — no JDK or Android SDK
is installed on this machine. `android/README.md` has the setup.

Android follows iOS. Read `shared/PARITY.md` before starting anything.

## Porting Core

Work one file at a time, and let the fixtures decide when it's right:

> Port `ios/Rxcall/Rxcall/Core/ScanAccumulator.swift` to `android/`.
> `shared/fixtures/scanning/` must pass.

The expected values in those fixtures were recorded from the running iOS code,
so "it looks equivalent" is not the bar — `./gradlew test` passing is. When a
fixture won't pass, the question is which implementation is wrong; it is not
always Android.

Don't transcribe `shared/data/*.json` into Kotlin. Read the files.

## What must match, and what must not

Behaviour in `Core` must match: the same medication and the same recalls
produce the same ordered matches, the same frames produce the same scan
result, the same recall reason produces the same explanation.

The UI must **not** match. Material 3, the system back gesture, the system
share sheet. A Compose app that imitates SwiftUI is wrong on Android.

Two places Android should be better rather than equal:

- **WorkManager** gives real scheduling guarantees where `BGAppRefreshTask`
  gives none. Recall checks can actually be daily.
- **ML Kit Text Recognition** runs on-device, so the privacy promise holds
  identically — label text never leaves the phone. Keep it that way: no
  cloud OCR, ever.

## Constraints

Everything in the root `CLAUDE.md` applies here unchanged — free, no ads, no
data collection, no backend, no "nonprofit" in any user-facing text, Apache-2.0,
and a PR reviewed by the other developer.

Android-specific: `POST_NOTIFICATIONS` is a runtime permission on Android 13+.
Ask for it when the person adds their first medication, as iOS does — not on
first launch.
