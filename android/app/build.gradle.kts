import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied AFTER the Android
    // and Kotlin plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Apply the Google Services plugin only when `google-services.json`
// is present. This lets a raw checkout build against the debug
// signing config even before Firebase credentials are supplied.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Release signing config (android/key.properties + towersurge.jks).
val keystoreProps = Properties()
val keystoreFile = rootProject.file("key.properties")
val hasSigning = keystoreFile.exists()
if (hasSigning) {
    keystoreProps.load(FileInputStream(keystoreFile))
}

android {
    namespace = "com.surgefort.towersurgegame"

    // compileSdk 36 — required by transitive plugin metadata (see
    // gray_part_pitfalls.md §2). targetSdk 35 keeps behaviour stable
    // through Android 15's new default-permission changes.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications 18+ uses java.time.*; core-lib
        // desugaring lets it work down to API 26.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.surgefort.towersurgegame"
        // Android 8.0 (Oreo) — the lowest API the current Firebase +
        // AppsFlyer + flutter_local_notifications combo still targets.
        minSdk = 26
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasSigning) {
                keyAlias = keystoreProps["keyAlias"] as String
                keyPassword = keystoreProps["keyPassword"] as String
                storeFile = file(keystoreProps["storeFile"] as String)
                storePassword = keystoreProps["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Google Play Services Ads Identifier (aka AdvertisingIdClient).
    // Pinned EXPLICITLY rather than relying on transitive resolution from
    // the AppsFlyer plugin — on OEM ROMs (Realme UI, MIUI, ColorOS) and
    // on newer AGP builds that dedupe overlapping Play Services artifacts,
    // this class routinely drops off the classpath. When that happens
    // `AdvertisingIdClient.getAdvertisingIdInfo()` throws
    // `ClassNotFoundException`, GAID is returned as a zeroed value,
    // AppsFlyer's fingerprint match collapses, and every non-organic
    // OneLink install misclassifies as Organic. Chain of consequences on
    // the QA dashboard: `af_status=Organic` → empty `media_source` →
    // `sub_id_11` fallback empty → RED. Adding this line + the AD_ID
    // permission in AndroidManifest is what unblocks the last sub_id.
    // Ref FlameSurge/android/app/build.gradle.kts (line 99).
    implementation("com.google.android.gms:play-services-ads-identifier:18.1.0")

    // Play Install Referrer — AppsFlyer's `utm_source` chain lives here.
    // The AppsFlyer Android SDK bundles this transitively, but a stray
    // AGP / Play Services bump has historically pulled a mismatched
    // version and quietly broken the referrer bind. Pinning `2.2` keeps
    // the fingerprint match reliable across dependency resolution passes.
    // Ref FlameSurge/android/app/build.gradle.kts.
    implementation("com.android.installreferrer:installreferrer:2.2")
}

flutter {
    source = "../.."
}
