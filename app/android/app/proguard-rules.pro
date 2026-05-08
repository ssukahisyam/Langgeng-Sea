# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Drift (SQLite)
-keep class com.tekartik.sqflite.** { *; }

# Geolocator & permission_handler
-keep class com.baseflow.** { *; }

# Background service
-keep class id.flutter.** { *; }

# Keep model classes with annotations
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
