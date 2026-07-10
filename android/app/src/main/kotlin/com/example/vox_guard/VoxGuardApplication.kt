package com.example.vox_guard

import io.flutter.app.FlutterApplication
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.os.Build

class VoxGuardApplication : FlutterApplication() {
    private var screenClickCount = 0
    private var lastClickTime: Long = 0
    private var screenReceiver: BroadcastReceiver? = null

    override fun onCreate() {
        super.onCreate()
        registerScreenReceiver()
    }

    private fun registerScreenReceiver() {
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
        }

        screenReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val action = intent?.action
                if (action == Intent.ACTION_SCREEN_ON || action == Intent.ACTION_SCREEN_OFF) {
                    val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    val isPanicEnabled = prefs.getBoolean("flutter.panic_button_enabled", true)
                    
                    if (!isPanicEnabled) {
                        screenClickCount = 0
                        return
                    }

                    val currentTime = System.currentTimeMillis()
                    if (currentTime - lastClickTime > 5000) { // Reset count if more than 5 seconds pass
                        screenClickCount = 0
                    }
                    
                    if (screenClickCount == 0) {
                        lastClickTime = currentTime
                    }
                    
                    screenClickCount++
                    
                    if (screenClickCount >= 4) { // 4 transitions (e.g. click power button 4 times)
                        screenClickCount = 0
                        triggerPanicSos(context)
                    }
                }
            }
        }
        registerReceiver(screenReceiver, filter)
    }

    private fun triggerPanicSos(context: Context?) {
        context?.let { ctx ->
            val launchIntent = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)?.apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra("trigger_sos", true)
            }
            
            val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            
            val pendingIntent = PendingIntent.getActivity(
                ctx, 
                0, 
                launchIntent, 
                pendingIntentFlags
            )

            val channelId = "voxguard_panic"
            val notificationManager = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    channelId,
                    "VoxGuard Panic Trigger",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Used to show emergency SOS screen"
                }
                notificationManager.createNotificationChannel(channel)
            }

            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(ctx, channelId)
            } else {
                Notification.Builder(ctx)
            }

            builder.setSmallIcon(android.R.drawable.ic_dialog_alert)
                .setContentTitle("VoxGuard Emergency")
                .setContentText("Panic Button Activated! Triggering SOS...")
                .setPriority(Notification.PRIORITY_MAX)
                .setFullScreenIntent(pendingIntent, true)
                .setAutoCancel(true)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                builder.setCategory(Notification.CATEGORY_ALARM)
            }

            notificationManager.notify(999, builder.build())
            
            try {
                ctx.startActivity(launchIntent)
            } catch (e: Exception) {
                // Background start may fail on Android 10+, but fullScreenIntent will handle it
            }
        }
    }
}
