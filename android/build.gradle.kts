// AGP 9 brings its own Kotlin support. Adding org.jetbrains.kotlin.android
// here doesn't just duplicate it, it fails the build — see android/README.md.
// The Compose compiler plugin is separate and *is* required, pinned to the
// Kotlin version AGP ships.
plugins {
    id("com.android.application") version "9.5.2" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.4.21" apply false
}
