# --- FLUTTER WRAPPER ---
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# --- FIX FOR BUILD ERROR (Google Play Core) ---
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# --- FIX FOR GOOGLE ML KIT (Safety) ---
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }

# --- CRITICAL FIX: Don't warn about missing language-specific classes ---
# This prevents R8 from failing when these classes are referenced but not present
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**