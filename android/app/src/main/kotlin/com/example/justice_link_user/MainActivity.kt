package com.example.justice_link_user

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "justice_link/notification"
    private val ALARM_PERMISSION_REQUEST = 2001

    companion object {
        private const val TAG = "MainActivity"
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        requestPermissions(
                            arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                            1
                        )
                    }
                    result.success(true)
                }

                "openNotificationSettings" -> {
                    val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                        putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    }
                    startActivity(intent)
                    result.success(true)
                }

                // 🔴 NEW: Check if exact alarms are allowed (Android 12+)
                "canScheduleExactAlarms" -> {
                    val canSchedule = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                        alarmManager.canScheduleExactAlarms()
                    } else {
                        true // Below Android 12, no permission needed
                    }
                    result.success(canSchedule)
                }

                // 🔴 NEW: Request exact alarm permission (Android 12+)
                "requestExactAlarmPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                            data = Uri.parse("package:$packageName")
                        }
                        startActivityForResult(intent, ALARM_PERMISSION_REQUEST)
                    }
                    result.success(true)
                }

                // 🔴 NEW: Schedule exact alarm for emergency checking
                "scheduleEmergencyAlarm" -> {
                    val delaySeconds = call.argument<Int>("delaySeconds") ?: 15
                    val receiver = EmergencyRestartReceiver()
                    receiver.scheduleExactAlarm(this, delaySeconds * 1000L)
                    result.success(true)
                }

                // 🔴 NEW: Cancel exact alarm
                "cancelEmergencyAlarm" -> {
                    val receiver = EmergencyRestartReceiver()
                    receiver.cancelExactAlarm(this)
                    result.success(true)
                }

                // 🔴 NEW: Open battery optimization settings
                "openBatteryOptimizationSettings" -> {
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                        data = Uri.parse("package:$packageName")
                    }
                    startActivity(intent)
                    result.success(true)
                }

                // 🔴 NEW: Check battery optimization status
                "isBatteryOptimizationDisabled" -> {
                    val powerManager = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                    val isDisabled = powerManager.isIgnoringBatteryOptimizations(packageName)
                    result.success(isDisabled)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Handle intent from notification tap when app was killed
        intent?.let { handleIntent(it) }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        when (intent.action) {
            "justice_link.EMERGENCY_ALERT" -> {
                Log.d(TAG, "🚨 App opened from emergency notification")
                // Notify Flutter to show emergency screen
                // This will be handled by the method channel when Flutter requests
            }
            Intent.ACTION_MAIN -> {
                // Normal app open
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == ALARM_PERMISSION_REQUEST) {
            // Check if permission was granted
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val granted = alarmManager.canScheduleExactAlarms()
                Log.d(TAG, "Exact alarm permission result: $granted")

                // Notify Flutter
                // You can use EventChannel or shared preferences to communicate this
            }
        }
    }
}