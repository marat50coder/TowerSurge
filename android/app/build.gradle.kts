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
}

flutter {
    source = "../.."
}
