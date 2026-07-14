package com.example.vox_guard

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.app.NotificationManager
import android.app.NotificationChannel
import android.app.PendingIntent
import androidx.core.app.NotificationCompat
import android.os.PowerManager
import android.media.RingtoneManager
import android.media.AudioAttributes

class FakeCallReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val caller = intent.getStringExtra("caller") ?: "mom"
        val ringtone = intent.getStringExtra("ringtone") ?: "ringtone_default"
        val imgPath = intent.getStringExtra("imgPath") ?: "images/Woman.png"

        try {
            // Wake up the screen if it is locked/black
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val wakeLock = powerManager.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "VoxGuard:FakeCallWakeUp"
            )
            wakeLock.acquire(10000) // Keep screen bright for 10 seconds

            // Setup intent to launch MainActivity
            val activityIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("trigger_fake_call", true)
                putExtra("caller", caller)
                putExtra("ringtone", ringtone)
                putExtra("imgPath", imgPath)
            }

            val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }

            val pendingIntent = PendingIntent.getActivity(
                context,
                999,
                activityIntent,
                pendingIntentFlags
            )

            // Setup notification channel with ringtone
            val channelId = "voxguard_fake_call"
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    channelId,
                    "VoxGuard Fake Call",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "This channel is used to trigger scheduled fake calls."
                    setSound(soundUri, AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                        .build())
                    enableVibration(true)
                }
                notificationManager.createNotificationChannel(channel)
            }

            val callerDisplayName = if (caller == "mom") "أمي (Mom)" else if (caller == "dad") "أبي (Dad)" else "الشرطة (Police)"

            // Build high-priority call notification
            val builder = NotificationCompat.Builder(context, channelId)
                .setSmallIcon(context.resources.getIdentifier("launcher_icon", "mipmap", context.packageName))
                .setContentTitle("إتصال وارد (Incoming Call)")
                .setContentText("اضغط للرد على $callerDisplayName")
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setFullScreenIntent(pendingIntent, true)
                .setSound(soundUri)
                .setVibrate(longArrayOf(1000, 1000, 1000, 1000))
                .setAutoCancel(true)

            notificationManager.notify(999, builder.build())
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
