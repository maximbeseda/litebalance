# --- Flutter ---
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# --- Play Core (Flutter deferred components / split installs) ---
# Flutter посилається на ці класи; без правил R8 кидає warning і може зрізати.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# --- AndroidX biometric (local_auth) ---
-keep class androidx.biometric.** { *; }

# --- Google Sign-In / Drive API ---
-keep class com.google.api.client.** { *; }
-keep class com.google.api.services.** { *; }
-dontwarn com.google.api.client.**
-dontwarn com.google.api.services.**

# --- drift / sqlite3 (нативний FFI; рефлексія не використовується, але на всяк) ---
-keep class drift.** { *; }
-dontwarn org.sqlite.**
