pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.6.0" apply false
    // Kotlin 2.2.20 required by flutter_tts 4.2.x which ships with
    // Kotlin 2.2.0 metadata. Older Kotlin compilers (2.0.x / 2.1.x)
    // refuse to read 2.2.0 metadata and crash with an internal
    // compiler error during flutter_tts' own `compileReleaseKotlin`
    // task. Compatibility matrix:
    //   AGP 8.6.0           -> supports Kotlin 1.9.x through 2.2.x
    //   Gradle 8.10.2       -> supports Kotlin Gradle plugin 2.2.x
    //   Our own MainActivity.kt and repo Kotlin sources are
    //   trivial and compatible with 2.2.x out of the box.
    // This bump is the fix recommended by the Flutter tool itself
    // (see "Your project requires a newer version of the Kotlin
    // Gradle plugin" in the failing release build log).
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
