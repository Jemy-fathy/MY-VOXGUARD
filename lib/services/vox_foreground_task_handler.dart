import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(VoxForegroundTaskHandler());
}

/// Background voice monitor — يعمل حتى لو الشاشة مقفولة (Android)
/// على iOS يعمل مع الـ foreground task ما دام التطبيق في الخلفية
class VoxForegroundTaskHandler extends TaskHandler {
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _isListening = false;
  bool _isVerifying = false;
  bool _sosTriggered = false;
  String _savedPhrase = '';
  double _sensitivity = 0.55;
  Timer? _loopTimer;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('[BG VoiceMonitor] ▶ Task started');

    await _loadSettings();

    if (_savedPhrase.isEmpty) {
      debugPrint('[BG VoiceMonitor] No phrase — stopping service');
      await FlutterForegroundTask.stopService();
      return;
    }

    debugPrint('[BG VoiceMonitor] Monitoring for phrase: "$_savedPhrase" | sensitivity: $_sensitivity');
    _startAudioLoop();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Watchdog: يعيد تشغيل الـ loop لو توقف لأي سبب
    if (!_isListening && !_isVerifying && !_sosTriggered) {
      debugPrint('[BG VoiceMonitor] 🔄 Watchdog restarting loop...');
      _startAudioLoop();
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _loopTimer?.cancel();
    try { _audioRecorder.dispose(); } catch (_) {}
    debugPrint('[BG VoiceMonitor] ■ Task destroyed');
  }

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/home');
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _savedPhrase = prefs.getString('voice_phrase') ?? '';
    double stored = prefs.getDouble('voice_sensitivity') ?? 0.55;
    _sensitivity = stored.clamp(0.20, 0.90);
    debugPrint('[BG VoiceMonitor] Settings loaded — phrase: "$_savedPhrase" | sensitivity: $_sensitivity');
  }

  void _startAudioLoop() {
    _loopTimer?.cancel();
    _recordAndVerify();
  }

  Future<void> _recordAndVerify() async {
    if (_sosTriggered) return;
    if (_isVerifying) return;

    _isListening = true;
    _isVerifying = true;
    String? currentAudioPath;

    try {
      if (!await _audioRecorder.hasPermission()) {
        debugPrint('[BG VoiceMonitor] ❌ Mic permission denied');
        _isVerifying = false;
        _isListening = false;
        _scheduleNext(delay: const Duration(seconds: 5));
        return;
      }

      final dir = await getTemporaryDirectory();
      currentAudioPath = '${dir.path}/bg_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: currentAudioPath,
      );

      // سجّل لمدة 4 ثواني
      await Future.delayed(const Duration(seconds: 4));
      final recorded = await _audioRecorder.stop();

      if (recorded != null && !_sosTriggered) {
        await _verifyVoice(recorded);
      }
    } catch (e) {
      debugPrint('[BG VoiceMonitor] Loop error: $e');
    } finally {
      _isVerifying = false;
      _isListening = false;

      // احذف الملف المؤقت فوراً لتوفير المساحة
      if (currentAudioPath != null) {
        try {
          final file = File(currentAudioPath);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }

      if (!_sosTriggered) {
        _scheduleNext();
      }
    }
  }

  void _scheduleNext({Duration delay = const Duration(milliseconds: 200)}) {
    _loopTimer?.cancel();
    _loopTimer = Timer(delay, () => _recordAndVerify());
  }

  Future<void> _verifyVoice(String audioPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final userId = prefs.getString('user_id') ?? 'unknown_user';

      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 8);
      dio.options.receiveTimeout = const Duration(seconds: 8);
      if (token != null) {
        dio.options.headers['Authorization'] = 'Bearer $token';
      }
      dio.options.headers['Accept'] = 'application/json';

      final formData = FormData.fromMap({
        'user_id': userId,
        'audio': await MultipartFile.fromFile(audioPath, filename: 'verify.wav'),
        'threshold': _sensitivity,
      });

      debugPrint('[BG VoiceMonitor] 📡 Sending audio (threshold=$_sensitivity)...');
      final response = await dio.post(ApiConfig.verifyVoice, data: formData);

      if (response.statusCode == 200) {
        final data = response.data;
        final bool isMatch = data['match'] ?? false;
        final double score = (data['score'] ?? 0.0).toDouble();

        debugPrint(
          '[BG VoiceMonitor] Result — match: $isMatch | score: ${(score * 100).toStringAsFixed(1)}% | threshold: ${(_sensitivity * 100).toStringAsFixed(0)}%',
        );

        if (isMatch && !_sosTriggered) {
          debugPrint('[BG VoiceMonitor] ✅✅ VOICE MATCHED — TRIGGERING SOS!');
          _triggerSOS();
        }
      } else {
        debugPrint('[BG VoiceMonitor] ⚠️ Server status: ${response.statusCode}');
      }
    } on DioException catch (e) {
      debugPrint('[BG VoiceMonitor] ⚠️ Network error (skipping): ${e.type}');
    } catch (e) {
      debugPrint('[BG VoiceMonitor] ⚠️ Unexpected error: $e');
    }
  }

  void _triggerSOS() async {
    _sosTriggered = true;
    _loopTimer?.cancel();

    // 🔊 تشغيل صوت الإنذار
    try {
      final player = AudioPlayer();
      await player.setSource(AssetSource('audio/modern_alert.mp3'));
      await player.setVolume(1.0);
      await player.setReleaseMode(ReleaseMode.stop);
      await player.resume();
      Future.delayed(const Duration(seconds: 3), () => player.stop());
    } catch (e) {
      debugPrint('[BG VoiceMonitor] Alarm error: $e');
    }

    // 🚨 تحديث الـ Notification على الشاشة المقفولة
    await FlutterForegroundTask.updateService(
      notificationTitle: '🚨 SOS ACTIVATED — VoxGuard',
      notificationText: 'Voice password detected! Emergency alert sent.',
    );

    // إرسال إشارة للـ App الرئيسي (لو مفتوح)
    FlutterForegroundTask.sendDataToMain({'action': 'trigger_sos'});

    // فتح التطبيق لشاشة الطوارئ
    await Future.delayed(const Duration(milliseconds: 500));
    if (Platform.isAndroid) {
      FlutterForegroundTask.launchApp('/emergency');
    } else if (Platform.isIOS) {
      try {
        await launchUrl(
          Uri.parse('voxguard://emergency'),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        await launchUrl(
          Uri.parse('voxguard://'),
          mode: LaunchMode.externalApplication,
        );
      }
    }
  }
}