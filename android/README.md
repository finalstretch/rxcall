# android/

Not scaffolded yet. The structure, rules and behavioural contract are in place
first, so the port has something to be held to.

## Setup — already done on this machine

There is no Homebrew here, so everything was installed by direct download into
the user's home directory, the same way `gh` was. No `sudo`, nothing in
`/usr/local`.

| | Version | Location |
|---|---|---|
| Temurin JDK | 21.0.13.1+2 LTS | `~/Library/Java/JavaVirtualMachines/` |
| Android SDK command-line tools | 23.0 | `~/Library/Android/sdk/cmdline-tools/latest` |
| Platform-tools (`adb`) | 37.0.3 | `~/Library/Android/sdk/platform-tools` |
| Platform | android-36 | `~/Library/Android/sdk/platforms` |
| Build-tools | 36.1.0 | `~/Library/Android/sdk/build-tools` |
| Emulator | 37.3.10 | `~/Library/Android/sdk/emulator` |
| System image | android-36 google_apis arm64-v8a | `~/Library/Android/sdk/system-images` |
| Gradle | 9.9.2 | `~/.local/gradle-9.9.2` |

About 6.5 GB in total. `~/.zshrc` exports `JAVA_HOME`, `ANDROID_HOME` and the
PATH entries; an AVD named `rxcall-api36` (Pixel 7, Android 16) already exists.

Real projects use the Gradle wrapper, so the system Gradle above is only for
generating one and for throwaway builds.

## What a probe build found

A minimal project was built end to end to check the toolchain, and it turned
up one thing worth knowing before scaffolding the real app:

**AGP 9 has built-in Kotlin support.** Adding `org.jetbrains.kotlin.android`
is not merely redundant, it fails the build outright:

```
The 'org.jetbrains.kotlin.android' plugin is no longer required for
Kotlin support since AGP 9.0.
```

Nearly every Android tutorial still lists both plugins. Use only
`com.android.application`. Current versions as of setup: AGP 9.5.2,
Gradle 9.9.2, Kotlin 2.4.21 (supplied by AGP).

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
