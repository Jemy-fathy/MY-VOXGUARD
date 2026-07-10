import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import '../config/api_config.dart';
import '../screens/emergency_screen.dart';
import 'noise_monitor_service.dart';

/// VoiceMonitorService — تسجّل صوت كل 4 ثواني وتتحقق منه مع AI
/// تعمل في الـ Foreground (التطبيق مفتوح أو الشاشة مقفولة مع foreground service)
class VoiceMonitorService {
  static final VoiceMonitorService _instance = VoiceMonitorService._internal();
  factory VoiceMonitorService() => _instance;
  VoiceMonitorService._internal();

  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _isMonitoring = false;
  bool _isVerifying = false;
  bool _sosTriggered = false;
  String _savedPhrase = '';
  double _sensitivity = 0.55; // 0.0 → 1.0
  Timer? _loopTimer;

  static GlobalKey<NavigatorState>? navigatorKey;

  bool get isMonitoring => _isMonitoring;
  bool get isSosTriggered => _sosTriggered;
  String get savedPhrase => _savedPhrase;

  final ValueNotifier<bool> monitoringNotifier = ValueNotifier<bool>(false);

  Future<void> init() async {
    await _loadSettings();
  }

  Future<void> loadSettingsOnly() async {
    await _loadSettings();
    debugPrint('[VoiceMonitor] Settings loaded');
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _savedPhrase = prefs.getString('voice_phrase') ?? '';
    // الـ sensitivity محفوظة كـ 0.0–1.0
    double stored = prefs.getDouble('voice_sensitivity') ?? 0.55;
    stored = stored.clamp(0.20, 0.90);
    _sensitivity = stored;
    debugPrint('[VoiceMonitor] Phrase: "$_savedPhrase" | Sensitivity: $_sensitivity');
  }

  /// ابدأ المراقبة — بيتحقق من الـ phrase كل دورة تسجيل
  Future<void> startMonitoring() async {
    if (_isMonitoring) return;
    if (_sosTriggered) return;

    NoiseMonitorService().stopMonitoring();
    await _loadSettings();

    if (_savedPhrase.isEmpty) {
      debugPrint('[VoiceMonitor] No phrase saved — skipping');
      return;
    }

    _isMonitoring = true;
    monitoringNotifier.value = true;
    debugPrint('[VoiceMonitor] ✅ Started monitoring for: "$_savedPhrase"');

    _startAudioLoop();
  }

  void stopMonitoring() {
    _isMonitoring = false;
    monitoringNotifier.value = false;
    _loopTimer?.cancel();
    _loopTimer = null;
    try {
      _audioRecorder.stop();
    } catch (_) {}
    debugPrint('[VoiceMonitor] ⛔ Monitoring STOPPED');
  }

  void _startAudioLoop() {
    _loopTimer?.cancel();
    _recordAndVerifyCycle();
  }

  Future<void> _recordAndVerifyCycle() async {
    if (!_isMonitoring || _isVerifying || _sosTriggered) return;

    _isVerifying = true;
    String? currentPath;

    try {
      if (!await _audioRecorder.hasPermission()) {
        debugPrint('[VoiceMonitor] ❌ Mic permission denied');
        _isVerifying = false;
        _scheduleNext(delay: const Duration(seconds: 5));
        return;
      }

      final dir = await getTemporaryDirectory();
      currentPath = '${dir.path}/vm_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: currentPath,
      );

      // سجّل 4 ثواني
      await Future.delayed(const Duration(seconds: 4));
      final recorded = await _audioRecorder.stop();

      if (recorded != null && !_sosTriggered) {
        await _verifyVoice(recorded);
      }
    } catch (e) {
      debugPrint('[VoiceMonitor] Audio loop error: $e');
    } finally {
      _isVerifying = false;

      // احذف الملف المؤقت فوراً
      if (currentPath != null) {
        try {
          final f = File(currentPath);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }

      if (_isMonitoring && !_sosTriggered) {
        _scheduleNext();
      }
    }
  }

  void _scheduleNext({Duration delay = const Duration(milliseconds: 200)}) {
    _loopTimer?.cancel();
    _loopTimer = Timer(delay, () => _recordAndVerifyCycle());
  }

  Future<void> _verifyVoice(String audioPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final userId = prefs.getString('user_id') ?? 'unknown_user';

      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 10);
      dio.options.receiveTimeout = const Duration(seconds: 10);
      if (token != null) {
        dio.options.headers['Authorization'] = 'Bearer $token';
      }
      dio.options.headers['Accept'] = 'application/json';

      final formData = FormData.fromMap({
        'user_id': userId,
        'audio': await MultipartFile.fromFile(audioPath, filename: 'verify.wav'),
        'threshold': _sensitivity,
      });

      debugPrint('[VoiceMonitor] 📡 Sending audio to AI (threshold=$_sensitivity)...');
      final response = await dio.post(ApiConfig.verifyVoice, data: formData);

      if (response.statusCode == 200) {
        final data = response.data;
        final bool isMatch = data['match'] ?? false;
        final double score = (data['score'] ?? 0.0).toDouble();

        debugPrint(
          '[VoiceMonitor] Result — match: $isMatch | score: ${(score * 100).toStringAsFixed(1)}% | threshold: ${(_sensitivity * 100).toStringAsFixed(0)}%',
        );

        if (isMatch && !_sosTriggered) {
          debugPrint('[VoiceMonitor] ✅✅ VOICE MATCHED — TRIGGERING SOS!');
          _triggerSOS();
        }
      } else {
        debugPrint('[VoiceMonitor] ⚠️ Server returned ${response.statusCode}');
      }
    } on DioException catch (e) {
      debugPrint('[VoiceMonitor] ⚠️ Network error (skipping): ${e.type}');
    } catch (e) {
      debugPrint('[VoiceMonitor] ⚠️ Unexpected error: $e');
    }
  }

  void _triggerSOS() async {
    _sosTriggered = true;
    stopMonitoring();

    // 🔊 تشغيل صوت الإنذار
    try {
      final player = AudioPlayer();
      await player.setSource(AssetSource('audio/modern_alert.mp3'));
      await player.setVolume(1.0);
      await player.setReleaseMode(ReleaseMode.stop);
      await player.resume();
      Future.delayed(const Duration(seconds: 5), () => player.stop());
    } catch (e) {
      debugPrint('[VoiceMonitor] Alarm error: $e');
    }

    // 🚨 فتح شاشة الطوارئ
    if (navigatorKey?.currentState != null) {
      navigatorKey!.currentState!.push(
        MaterialPageRoute(builder: (context) => const EmergencyScreen()),
      );
    } else {
      debugPrint('[VoiceMonitor] ⚠️ Navigator key not available');
    }
  }

  void resetSos() {
    _sosTriggered = false;
  }

  void dispose() {
    stopMonitoring();
    _audioRecorder.dispose();
  }
}
