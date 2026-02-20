# ============================================
# FLUTTER CORE
# ============================================

-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.embedding.** { *; }

# 🔴 ADDED: Critical for plugin registration
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
-keep class io.flutter.embedding.engine.plugins.util.GeneratedPluginRegister { *; }

# --- FIX FOR BUILD ERROR (Google Play Core) ---
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# ============================================
# 🔴 ADDED: CRITICAL FIX FOR RELEASE BUILD CRASH
# ============================================

-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes SourceFile
-keepattributes LineNumberTable

# Keep all native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# ============================================
# 🔴 ADDED: FFMPEG KIT FIX
# ============================================

-keep class com.antonkarpenko.ffmpegkit.** { *; }
-keep class com.arthenica.ffmpegkit.** { *; }
-keep class com.arthenica.mobileffmpeg.** { *; }
-keepclassmembers class com.antonkarpenko.ffmpegkit.AbiDetect {
    native <methods>;
}
-dontwarn com.antonkarpenko.ffmpegkit.**
-dontwarn com.arthenica.ffmpegkit.**
-dontwarn com.arthenica.mobileffmpeg.**

# ============================================
# 🔴 ADDED: SHARED PREFERENCES FIX
# ============================================

-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class dev.flutter.pigeon.shared_preferences_android.** { *; }
-dontwarn dev.flutter.pigeon.shared_preferences_android.**

# ============================================
# 🔴 ADDED: BACKGROUND FETCH FIX
# ============================================

-keep class com.transistorsoft.flutter.backgroundfetch.BootReceiver {
    <init>();
    *;
}
-keep class com.transistorsoft.flutter.backgroundfetch.HeadlessTask { *; }
-keep class com.transistorsoft.flutter.backgroundfetch.BackgroundFetchModule { *; }
-keep class com.transistorsoft.flutter.backgroundfetch.BackgroundFetchPlugin { *; }
-keep class com.transistorsoft.** { *; }
-dontwarn com.transistorsoft.**

# ============================================
# 🔴 ADDED: BACKGROUND SERVICE FIX
# ============================================

-keep class id.flutter.flutter_background_service.BackgroundService {
    <init>();
    *;
}
-keepclassmembers class id.flutter.flutter_background_service.BackgroundService {
    <init>(...);
    *;
}

# ============================================
# EMERGENCY ALARM SYSTEM (Your existing code)
# ============================================

-keep class android.app.AlarmManager { *; }
-keep class android.app.PendingIntent { *; }
-keep class android.app.AlarmManager$* { *; }
-keep class android.os.PowerManager { *; }
-keep class android.os.PowerManager$WakeLock { *; }
-keep class android.os.PowerManager$OnWakeLockReleasedListener { *; }
-keep class com.example.justice_link_user.EmergencyRestartReceiver { *; }
-keep class com.example.justice_link_user.MainActivity { *; }
-keep class * extends android.content.BroadcastReceiver { *; }
-keep class io.flutter.plugin.common.MethodChannel { *; }
-keep class io.flutter.plugin.common.MethodCall { *; }
-keep class io.flutter.plugin.common.MethodChannel$Result { *; }
-keep class io.flutter.plugin.common.MethodChannel$MethodCallHandler { *; }
-keep class android.content.Intent { *; }
-keep class android.os.Bundle { *; }

# ============================================
# BACKGROUND SERVICES (Your existing code)
# ============================================

-keep class id.flutter.flutter_background_service.** { *; }
-keep class id.flutter.flutter_background_service.BackgroundService { *; }
-keep class com.transistorsoft.flutter.backgroundfetch.** { *; }
-keep class com.transistorsoft.flutter.backgroundfetch.HeadlessTask { *; }

-keep class androidx.work.** { *; }
-keep class androidx.work.impl.** { *; }
-keep class * extends androidx.work.Worker {
    <init>(android.content.Context, androidx.work.WorkerParameters);
    *;
}
-keep class * extends androidx.work.ListenableWorker {
    <init>(android.content.Context, androidx.work.WorkerParameters);
    *;
}
-dontwarn androidx.work.**

# ============================================
# LOCATION SERVICES (Your existing code)
# ============================================

-keep class com.baseflow.geolocator.** { *; }
-keep class com.baseflow.geolocator.GeolocatorLocationService { *; }
-keep class com.baseflow.geolocator.location.** { *; }
-keep class com.google.android.gms.location.** { *; }
-keep class com.google.android.gms.common.** { *; }

# ============================================
# NOTIFICATIONS (Your existing code)
# ============================================

-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
-keep class com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin { *; }
-keep class me.carda.awesome_notifications.** { *; }
-keep class android.app.NotificationChannel { *; }
-keep class android.app.NotificationManager { *; }
-keep class androidx.core.app.NotificationCompat { *; }
-keep class androidx.core.app.NotificationCompat$* { *; }

# ============================================
# SUPABASE & NETWORKING (Your existing code)
# ============================================

-keep class io.supabase.** { *; }
-keep class com.supabase.** { *; }
-keep class io.github.jan.supabase.** { *; }
-keep class io.github.jan.supabase.realtime.** { *; }
-keep class io.github.jan.supabase.postgrest.** { *; }
-keep class okhttp3.** { *; }
-keep class retrofit2.** { *; }
-dontwarn okhttp3.**
-dontwarn retrofit2.**

-keep class kotlinx.serialization.** { *; }
-keepclassmembers class * {
    @kotlinx.serialization.Serializable <fields>;
}

# ============================================
# GOOGLE ML KIT (Your existing code)
# ============================================

-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ============================================
# FIREBASE (Your existing code)
# ============================================

-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.firebase.messaging.** { *; }

# ============================================
# ANDROIDX & SUPPORT LIBRARIES (Your existing code)
# ============================================

-keep class androidx.core.** { *; }
-keep class androidx.core.content.** { *; }
-keep class androidx.lifecycle.** { *; }
-keep class * implements androidx.lifecycle.LifecycleObserver { *; }
-keep class androidx.localbroadcastmanager.content.LocalBroadcastManager { *; }

# ============================================
# SHARED PREFERENCES & STORAGE (Your existing code)
# ============================================

-keep class android.content.SharedPreferences { *; }
-keep class android.content.SharedPreferences$Editor { *; }
-keep class androidx.core.content.FileProvider { *; }

# ============================================
# AUDIO & VIBRATION (Your existing code)
# ============================================

-keep class xyz.luan.audioplayers.** { *; }
-keep class com.benjaminabel.vibration.** { *; }

# ============================================
# PERMISSION HANDLER (Your existing code)
# ============================================

-keep class com.baseflow.permissionhandler.** { *; }

# ============================================
# WAKE LOCK & BATTERY (Your existing code)
# ============================================

-keep class dev.fluttercommunity.plus.wakelock.** { *; }
-keep class com.judemanutd.autostarter.** { *; }

# ============================================
# PREVENT OBFUSCATION (Your existing code)
# ============================================

-keep class com.example.justice_link_user.** { *; }
-keepclasseswithmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}