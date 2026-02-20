package com.yourpackage.justice_link_user  // Change to your package

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.view.FlutterCallbackInformation
import io.flutter.embedding.engine.loader.FlutterLoader
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.d("BootReceiver", "Device booted, restarting emergency services...")

            // Start the background service
            val serviceIntent = Intent(context, id.flutter.flutter_background_service.BackgroundService::class.java)
            context.startForegroundService(serviceIntent)
        }
    }
}