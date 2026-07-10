import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'vox_foreground_task_handler.dart';

class BackgroundMonitorService {
  // ── Singleton ──
  static final BackgroundMonitorService _instance =
      BackgroundMonitorService._internal();
  factory BackgroundMonitorService() => _instance;
  BackgroundMonitorService._internal();

  /// Initialize foreground task settings. Call once on app start (before runApp).
  static void initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'voxguard_voice_monitor',
        channelName: 'VoxGuard Voice Monitor',
        channelDescription:
            'Keeps VoxGuard active to detect your emergency phrase when the screen is locked.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(10000), // watchdog every 10s
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Register a callback to receive data from the background isolate.
  /// Call this from your widget's initState.
  void addDataCallback(DataCallback callback) {
    FlutterForegroundTask.addTaskDataCallback(callback);
  }

  /// Remove a previously registered data callback.
  void removeDataCallback(DataCallback callback) {
    FlutterForegroundTask.removeTaskDataCallback(callback);
  }

  /// Start background voice monitoring.
  /// Shows a persistent notification and keeps listening even when locked.
  Future<bool> startBackgroundMonitoring() async {
    // Request notification permission if not granted
    final NotificationPermission notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (await FlutterForegroundTask.isRunningService) {
      debugPrint('[BGMonitor] Service already running.');
      return true;
    }

    final ServiceRequestResult result = await FlutterForegroundTask.startService(
      serviceId: 7749,
      notificationTitle: '🛡️ VoxGuard يحميك',
      notificationText: 'المراقبة الصوتية نشطة — قل الكلمة عند الخطر',
      callback: startCallback,
    );

    final bool success = result is ServiceRequestSuccess;
    debugPrint('[BGMonitor] Start result: $success');
    return success;
  }

  /// Stop background voice monitoring.
  Future<bool> stopBackgroundMonitoring() async {
    final ServiceRequestResult result =
        await FlutterForegroundTask.stopService();
    final bool success = result is ServiceRequestSuccess;
    debugPrint('[BGMonitor] Stop result: $success');
    return success;
  }

  /// Check if background monitoring is currently running.
  Future<bool> get isRunning => FlutterForegroundTask.isRunningService;
}
