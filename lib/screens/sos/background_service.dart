import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../config/api_config.dart';
import 'ai_monitor.dart';

const String kSosBgLogKey = 'sos_bg_log';
const int _kSosLogMaxEntries = 500;
int? activeSosIdInMemory;

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'voxguard_emergency',
      initialNotificationTitle: 'VoxGuard Active',
      initialNotificationContent: 'AI Monitor is running',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(autoStart: false, onForeground: onStart),
  );
  await service.startService();
  print("SERVICE STARTED REQUEST SENT");
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WakelockPlus.enable();
  print("========== BACKGROUND SERVICE STARTED ==========");
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
  }

  final prefs = await SharedPreferences.getInstance();
  final audioRecorder = AudioRecorder();

  runAiMonitorLoop(service);

  service.on('updateEmotionStatus').listen((event) async {
    bool enabled = event?['enabled'] ?? false;
    await prefs.setBool(kEmotionDetectionKey, enabled);
    _log('🧠 Emotion Detection updated to: $enabled');
  });

  service.on('updateAiStatus').listen((event) async {
    bool enabled = event?['enabled'] ?? false;
    await prefs.setBool(kAiAutoModeKey, enabled);
    _log('🤖 AI Mode updated to: $enabled');
  });

  service.on('startManualSos').listen((event) async {
    final reason = event?['reason'] ?? 'Manual SOS';
    final path = event?['evidence_path'];
    await triggerSos(
      isManual: reason == 'manual',
      reason: reason,
      emotion: reason == 'ai_emotion_confirmed' ? 'detected' : null,
      evidencePath: path,
    );
  });

  service.on('stopSosSafe').listen((_) async {
    await audioRecorder.stop();
    await prefs.setBool('sos_active', false);
    await prefs.remove('active_sos_id');
    activeSosIdInMemory = null;
    _log('✅ SOS Stopped.');
  });

  service.on('scheduleBackgroundFakeCall').listen((event) async {
    if (event == null) return;
    int seconds = event['seconds'] ?? 0;
    String caller = event['caller'] ?? 'mom';
    String ringtone = event['ringtone'] ?? 'ringtone_default';
    String imgPath = event['imgPath'] ?? 'images/Woman.png';

    if (Platform.isAndroid) {
      try {
        const panicChannel = MethodChannel('com.example.vox_guard/panic');
        await panicChannel.invokeMethod('scheduleNativeFakeCall', {
          'seconds': seconds,
          'caller': caller,
          'ringtone': ringtone,
          'imgPath': imgPath,
        });
        _log('✅ Native exact AlarmManager scheduled successfully.');
        return; // Return early, AlarmManager handles the callback
      } catch (e) {
        _log('⚠️ Failed to schedule native exact AlarmManager, using fallback Timer: $e');
      }
    }

    Timer(Duration(seconds: seconds), () async {
      // Send event back to main UI thread
      service.invoke('triggerFakeCallNow', {
        'caller': caller,
        'ringtone': ringtone,
        'imgPath': imgPath,
      });
    });
  });

  service.invoke('serviceStarted');
}

Future<void> triggerSos(
    {required bool isManual,
    String? emotion,
    String? evidencePath,
    required String reason}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('sos_active', true);
  await prefs.setBool('should_show_sos_screen', true);

  if (Platform.isAndroid) {
    try {
      const panicChannel = MethodChannel('com.example.vox_guard/panic');
      await panicChannel.invokeMethod('showSosNotification');
    } catch (e) {
      debugPrint('Failed to show native SOS notification: $e');
    }
  }

  await _log('🚨 SOS Triggered! Manual: $isManual, Emotion: $emotion');

  Position? pos;
  try {
    pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  } catch (e) {
    await _log('❌ Location fetch error: $e');
  }

  try {
    final response = await http.post(
      Uri.parse('${ApiConfig.sosBaseUrl}/start'),
      headers: {
        'Authorization': 'Bearer ${prefs.getString('auth_token')}',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({
        'latitude': pos?.latitude.toString() ?? '0.0',
        'longitude': pos?.longitude.toString() ?? '0.0',
        'trigger_type': isManual ? 'manual' : 'sentiment_analysis',
        'emotion': emotion ?? 'unknown',
      }),
    );

    if (response.statusCode == 200) {
      final sosId = jsonDecode(response.body)['sos_id'];
      await prefs.setInt('active_sos_id', sosId);
      activeSosIdInMemory = sosId;

      if (evidencePath != null && await File(evidencePath).exists()) {
        await uploadRecordingToBackend(evidencePath, sosId: sosId);
      }

      _runLocationReportingLoop(sosId, prefs.getString('auth_token') ?? '');
      await _log('✅ SOS Process initialized with ID: $sosId');
    } else {
      await _log('❌ Server rejected SOS: ${response.statusCode}');
    }
  } catch (e) {
    await _log('❌ SOS Start Error: $e');
  }
}

Future<void> uploadRecordingToBackend(String filePath,
    {required int sosId}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    var request = http.MultipartRequest(
        'POST', Uri.parse('${ApiConfig.sosBaseUrl}/$sosId/upload-audio'));
    request.files
        .add(await http.MultipartFile.fromPath('audio_file', filePath));
    request.headers
        .addAll({'Authorization': 'Bearer ${prefs.getString('auth_token')}'});
    await request.send();
    await _log('📤 Audio evidence uploaded for SOS: $sosId');
  } catch (e) {
    await _log('❌ Error uploading audio: $e');
  }
}

Future<void> _runLocationReportingLoop(int sosId, String token) async {
  await _log('📍 Location loop started for SOS: $sosId');
  while (true) {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('sos_active') != true) break;
    try {
      Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      await http.post(
        Uri.parse('${ApiConfig.sosBaseUrl}/$sosId/update-location'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body:
            jsonEncode({'latitude': pos.latitude, 'longitude': pos.longitude}),
      );
    } catch (e) {
      await _log('❌ Location loop error: $e');
    }
    await Future.delayed(const Duration(seconds: 30));
  }
}

Future<void> _log(String message) async {
  print('[BG-SOS] $message');
  try {
    final prefs = await SharedPreferences.getInstance();
    final List<String> log = prefs.getStringList(kSosBgLogKey) ?? <String>[];
    log.add('${DateTime.now().toIso8601String()} | $message');
    if (log.length > _kSosLogMaxEntries) {
      log.removeRange(0, log.length - _kSosLogMaxEntries);
    }
    await prefs.setStringList(kSosBgLogKey, log);
  } catch (_) {}
}
