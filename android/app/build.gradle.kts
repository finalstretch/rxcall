plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "org.finalstretch.rxcall"
    // Compose 1.13 requires compiling against 37.1+. targetSdk stays at 36
    // because that's the newest platform with an arm64 emulator image, so
    // it's the newest runtime behaviour we can actually test here. Raise it
    // when an android-37 image ships.
    compileSdk = 37
    compileSdkMinor = 2

    defaultConfig {
        applicationId = "org.finalstretch.rxcall"
        // Android 8.0. Notification channels arrived here, which the recall
        // alerts need, and anything older can't run a modern app comfortably.
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "0.1"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildFeatures { compose = true }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }

    testOptions {
        unitTests.all {
            // Fixtures are read from shared/ by relative path; pin the working
            // directory so it doesn't depend on how Gradle was invoked.
            it.workingDir = rootProject.projectDir
        }
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.19.1")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.11.1")
    implementation("androidx.activity:activity-compose:1.13.0")
    implementation(platform("androidx.compose:compose-bom:2026.11.01"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("com.google.code.gson:gson:2.15.0")

    testImplementation("junit:junit:4.13.2")
    testImplementation("com.google.code.gson:gson:2.15.0")
}
