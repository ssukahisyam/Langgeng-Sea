import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// -----------------------------------------------------------------------------
// Release signing configuration
// -----------------------------------------------------------------------------
// Signing credentials are loaded from `android/key.properties` (gitignored).
// The file is NOT committed. See RELEASE_CHECKLIST.md for how to generate the
// keystore and populate key.properties on the release workstation.
//
// Expected keys in key.properties:
//   storeFile=../release.keystore      (path relative to android/app/)
//   storePassword=...
//   keyAlias=...
//   keyPassword=...
//
// When key.properties is missing, release builds fall back to debug signing.
// This lets CI produce installable (but unsigned-for-Play-Store) release APKs
// without requiring secrets, while local release builds by a signing key
// holder produce Play-Store-ready artefacts.
// -----------------------------------------------------------------------------
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "id.co.langgengsea"
    // flutter_tts 4.2.x bumped its Android target and requires
    // compileSdk 36. Override Flutter's default (currently 35) so
    // release builds stop failing with:
    //   "flutter_tts compiles against Android SDK 36"
    // The higher compileSdk is backward compatible (minSdk stays
    // at 26 per PRD NFR-04, so no existing device is affected).
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    defaultConfig {
        applicationId = "id.co.langgengsea"
        // Min SDK 26 (Android 8.0) per PRD NFR-04
        minSdk = 26
        // Target SDK 34 (Android 14) — pinned explicitly so the
        // foreground-service-type location contract declared in
        // AndroidManifest.xml is enforced against the API level we
        // actually test against. Requirement 1 AC 10.
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                val storeFilePath = keystoreProperties["storeFile"] as String?
                if (storeFilePath != null) {
                    storeFile = file(storeFilePath)
                }
                storePassword = keystoreProperties["storePassword"] as String?
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            // Use the real release signing config when key.properties exists,
            // otherwise fall back to debug signing so CI can still produce
            // installable artefacts for smoke testing.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            isMinifyEnabled = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.2")
}
