package com.example.vox_guard

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import android.view.WindowManager
import android.os.Build
import android.content.Intent
import io.flutter.plugin.common.MethodChannel
import android.app.NotificationManager
import android.app.NotificationChannel
import android.app.PendingIntent
import androidx.core.app.NotificationCompat

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.vox_guard/panic"
    private var pendingTriggerSos = false
    private var pendingFakeCallData: Map<String, String>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }

        handleIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "checkPendingTrigger") {
                result.success(pendingTriggerSos)
                pendingTriggerSos = false // Reset after checking
            } else if (call.method == "checkPendingFakeCall") {
                result.success(pendingFakeCallData)
                pendingFakeCallData = null // Reset after checking
            } else if (call.method == "showFakeCallNotification") {
                val caller = call.argument<String>("caller") ?: "mom"
                val ringtone = call.argument<String>("ringtone") ?: "ringtone_default"
                val imgPath = call.argument<String>("imgPath") ?: "images/Woman.png"
                showNativeNotification(caller, ringtone, imgPath)
                result.success(true)
            } else if (call.method == "showSosNotification") {
                showNativeSosNotification()
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent?.getBooleanExtra("trigger_sos", false) == true) {
            pendingTriggerSos = true
            // Invoke immediately if the engine is running
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, CHANNEL).invokeMethod("triggerPanicSos", null)
            }
        }
        if (intent?.getBooleanExtra("trigger_fake_call", false) == true) {
            val caller = intent.getStringExtra("caller") ?: "mom"
            val ringtone = intent.getStringExtra("ringtone") ?: "ringtone_default"
            val imgPath = intent.getStringExtra("imgPath") ?: "images/Woman.png"
            
            val data = mapOf(
                "caller" to caller,
                "ringtone" to ringtone,
                "imgPath" to imgPath
            )
            pendingFakeCallData = data
            // Invoke immediately if the engine is running
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, CHANNEL).invokeMethod("triggerFakeCallNow", data)
            }
        }
    }

    private fun showNativeNotification(caller: String, ringtone: String, imgPath: String) {
        try {
            val intent = Intent(this, MainActivity::class.java).apply {
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
                this,
                999,
                intent,
                pendingIntentFlags
            )

            val channelId = "voxguard_fake_call"
            val notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    channelId,
                    "VoxGuard Fake Call",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "This channel is used to trigger scheduled fake calls."
                }
                notificationManager.createNotificationChannel(channel)
            }

            val callerDisplayName = if (caller == "mom") "أمي (Mom)" else if (caller == "dad") "أبي (Dad)" else "الشرطة (Police)"

            val builder = NotificationCompat.Builder(this, channelId)
                .setSmallIcon(resources.getIdentifier("launcher_icon", "mipmap", packageName))
                .setContentTitle("إتصال وارد (Incoming Call)")
                .setContentText("اضغط للرد على $callerDisplayName")
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setFullScreenIntent(pendingIntent, true)
                .setAutoCancel(true)

            notificationManager.notify(999, builder.build())
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun showNativeSosNotification() {
        try {
            val intent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("trigger_sos", true)
            }
            
            val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }

            val pendingIntent = PendingIntent.getActivity(
                this,
                888,
                intent,
                pendingIntentFlags
            )

            val channelId = "voxguard_emergency"
            val notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    channelId,
                    "VoxGuard Emergency",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "This channel is used to trigger background emergency screens."
                }
                notificationManager.createNotificationChannel(channel)
            }

            val builder = NotificationCompat.Builder(this, channelId)
                .setSmallIcon(resources.getIdentifier("launcher_icon", "mipmap", packageName))
                .setContentTitle("تنبيه أمان (VoxGuard SOS)")
                .setContentText("جاري تشغيل وضع الاستغاثة والطوارئ...")
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setFullScreenIntent(pendingIntent, true)
                .setAutoCancel(true)

            notificationManager.notify(888, builder.build())
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
