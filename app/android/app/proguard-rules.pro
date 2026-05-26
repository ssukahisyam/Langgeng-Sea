# -----------------------------------------------------------------------------
# Styra — ProGuard / R8 rules for release builds
# -----------------------------------------------------------------------------
# When `isMinifyEnabled = true` R8 strips unused code and renames symbols.
# Native / reflection-based code paths must be explicitly kept here, otherwise
# the release APK will crash at runtime with NoSuchMethod / ClassNotFound.
# -----------------------------------------------------------------------------

# ---------- Flutter engine ---------------------------------------------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# ---------- Kotlin / Coroutines ----------------------------------------------
-keep class kotlin.Metadata { *; }
-keepclassmembers class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# ---------- Drift / SQLite (sqlite3_flutter_libs) ----------------------------
# Drift itself is pure Dart, but the native SQLite bindings go through JNI.
-keep class com.tekartik.sqflite.** { *; }
-keep class org.sqlite.** { *; }
-dontwarn org.sqlite.**

# ---------- flutter_map ------------------------------------------------------
# flutter_map is pure Dart, no native keep needed, but its tile providers
# reference OkHttp-style helpers occasionally pulled in by plugins.
-dontwarn org.dartlang.flutter_map.**

# ---------- flutter_map_tile_caching (FMTC) ----------------------------------
# FMTC uses ObjectBox natively for its store; keep the ObjectBox generated
# entities & native API.
-keep class io.objectbox.** { *; }
-keep class **$$ObjectBox** { *; }
-keepclassmembers class * {
    @io.objectbox.annotation.* *;
}
-dontwarn io.objectbox.**

# ---------- phosphor_flutter -------------------------------------------------
# Icons are loaded from font assets via PathHandle reflection in release.
-keep class com.phosphor.** { *; }
-dontwarn com.phosphor.**

# ---------- Riverpod ---------------------------------------------------------
# Riverpod is pure Dart; keeping annotated classes protects codegen output
# from accidental shrink when called from native plugins.
-keep class **$Ref { *; }
-keep class **Provider { *; }
-dontwarn riverpod.**

# ---------- geolocator -------------------------------------------------------
-keep class com.baseflow.geolocator.** { *; }
-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.**

# ---------- permission_handler -----------------------------------------------
-keep class com.baseflow.permissionhandler.** { *; }

# ---------- flutter_background_service ---------------------------------------
-keep class id.flutter.** { *; }
-keep class dev.fluttercommunity.plus.** { *; }

# ---------- flutter_local_notifications --------------------------------------
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**

# ---------- Gson / JSON (used by share_plus, geolocator internals) ----------
-keepattributes Signature
-keepattributes *Annotation*
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# ---------- Android platform -------------------------------------------------
# Keep enclosing method info for stacktraces post-obfuscation.
-keepattributes EnclosingMethod,InnerClasses,SourceFile,LineNumberTable

# ---------- Desugar library --------------------------------------------------
-dontwarn java.lang.invoke.**
-dontwarn com.android.tools.r8.**


# ---------- Play Core (deferred components) ----------------------------------
# Flutter embedding references com.google.android.play.core.* classes as
# part of its deferred-components feature (split APKs downloaded at
# runtime via Play Store). We do NOT use deferred components, so those
# dependencies are not on the classpath. Tell R8 these missing
# references are fine — the code path is never executed in our app.
#
# Without this, `flutter build apk --release` fails at :app:minifyReleaseWithR8
# with "Missing class com.google.android.play.core.splitcompat.*" and ~10
# sibling classes.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
