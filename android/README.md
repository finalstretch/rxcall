# android/

Not scaffolded yet. The structure, rules and behavioural contract are in place
first, so the port has something to be held to.

## Setup

Nothing is installed on the build machine yet — no JDK, no Android SDK, no
Android Studio.

```
brew install --cask temurin@21        # arm64 JDK
brew install --cask android-studio    # or just the commandline-tools
```

## On this machine

A Mac mini M2 with 8 GB of RAM. Android Studio, a Gradle daemon and an emulator
together will thrash it, especially alongside Xcode. Two things help:

- **Use a real Android phone over USB instead of the emulator.** Cheaper on
  memory, and every real bug in the iOS app came from a physical device —
  pharmacy labels without lot numbers, box-only NDCs, a misread cream.
- **Build from the command line.** `./gradlew assembleDebug` and
  `adb install`, the same way the iOS app is built with `xcodebuild` and
  `simctl` without opening Xcode.

## Testing before a Play Console account

All of this works with no account and no fee:

- `./gradlew assembleDebug` then `adb install app-debug.apk`. Gradle generates
  a debug keystore; there is no equivalent of the `.p12` and provisioning
  profile ordeal.
- Firebase App Distribution for friends — free, no Play Console, the closest
  thing to TestFlight.

The $25 Play Console is needed only for Play Store tracks and production. Note
that a personal developer account created after 13 November 2023 must run a
closed test with at least 12 testers opted in continuously for 14 days before
applying for production access. Start that clock as soon as there's an
installable build; it runs in parallel with finishing the app.
