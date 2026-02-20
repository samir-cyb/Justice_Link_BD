package com.example.justice_link_user

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.util.Log
import androidx.core.content.ContextCompat
import java.util.*

class EmergencyRestartReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "EmergencyRestart"
        private const val ALARM_REQUEST_CODE = 1001
        private const val INTERVAL_MILLIS = 15000L // 15 seconds for aggressive mode
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.d(TAG, "📡 Received broadcast: $action")

        when (action) {
            Intent.ACTION_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON" -> {
                Log.d(TAG, "🔄 Phone booted, starting emergency monitoring")

                // Start foreground service immediately
                startForegroundService(context)

                // Schedule exact alarm for aggressive checking
                scheduleExactAlarm(context, delayMillis = 10000) // 10 second initial delay
            }

            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                Log.d(TAG, "🔄 App updated, restarting emergency monitoring")
                startForegroundService(context)
                scheduleExactAlarm(context, delayMillis = 5000) // 5 second delay
            }

            "justice_link.EXACT_ALARM_FIRED" -> {
                Log.d(TAG, "⏰ Exact alarm fired - checking emergencies")

                // Wake up device
                val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                val wakeLock = powerManager.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                    "JusticeLink:EmergencyCheck"
                )
                wakeLock.acquire(30000) // 30 seconds max

                // Start foreground service to do the check
                startForegroundService(context)

                // Reschedule next alarm
                scheduleExactAlarm(context, delayMillis = INTERVAL_MILLIS)

                wakeLock.release()
            }
        }
    }

    private fun startForegroundService(context: Context) {
        try {
            val serviceIntent = Intent(context, id.flutter.flutter_background_service.BackgroundService::class.java)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ContextCompat.startForegroundService(context, serviceIntent)
            } else {
                context.startService(serviceIntent)
            }

            Log.d(TAG, "✅ Foreground service started")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to start foreground service: ${e.message}")
        }
    }

    /**
     * 🔴 CRITICAL: Uses AlarmManager for exact 15-second intervals
     * WorkManager CANNOT do this - minimum is 15 minutes
     */
    fun scheduleExactAlarm(context: Context, delayMillis: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, EmergencyRestartReceiver::class.java).apply {
            action = "justice_link.EXACT_ALARM_FIRED"
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            ALARM_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val triggerTime = System.currentTimeMillis() + delayMillis

        try {
            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
                    // Android 12+ - need permission
                    if (alarmManager.canScheduleExactAlarms()) {
                        alarmManager.setExactAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            triggerTime,
                            pendingIntent
                        )
                        Log.d(TAG, "✅ Exact alarm scheduled for ${Date(triggerTime)} (Android 12+)")
                    } else {
                        Log.w(TAG, "⚠️ Cannot schedule exact alarms - permission not granted")
                        // Fallback to inexact
                        alarmManager.setAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            triggerTime,
                            pendingIntent
                        )
                    }
                }
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                    // Android 6-11
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        triggerTime,
                        pendingIntent
                    )
                    Log.d(TAG, "✅ Exact alarm scheduled for ${Date(triggerTime)} (Android 6-11)")
                }
                else -> {
                    // Below Android 6
                    alarmManager.setExact(
                        AlarmManager.RTC_WAKEUP,
                        triggerTime,
                        pendingIntent
                    )
                    Log.d(TAG, "✅ Exact alarm scheduled for ${Date(triggerTime)} (Legacy)")
                }
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ SecurityException scheduling alarm: ${e.message}")
            // Fallback
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerTime,
                pendingIntent
            )
        }
    }

    fun cancelExactAlarm(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, EmergencyRestartReceiver::class.java).apply {
            action = "justice_link.EXACT_ALARM_FIRED"
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            ALARM_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        alarmManager.cancel(pendingIntent)
        Log.d(TAG, "✅ Exact alarm cancelled")
    }
}