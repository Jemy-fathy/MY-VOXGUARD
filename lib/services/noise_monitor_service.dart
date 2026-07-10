import 'dart:async';
import 'package:flutter/material.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/emergency_screen.dart';

/// Singleton service that monitors environmental decibel levels.
/// If noise levels exceed a custom threshold for a sustained duration,
/// it automatically triggers the SOS flow.
class NoiseMonitorService {
  // ── Singleton ──
  static final NoiseMonitorService _instance = NoiseMonitorService._internal();
  factory NoiseMonitorService() => _instance;
  NoiseMonitorService._internal();

  // ── Dependencies ──
  NoiseMeter? _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSubscription;

  // ── State ──
  bool _isMonitoring = false;
  double _threshold = 85.0; // Default threshold in dB
  double _currentDecibel = 0.0;
  int _consecutiveLoudReadings = 0;

  // ── Global navigator key (set from main.dart) ──
  static GlobalKey<NavigatorState>? navigatorKey;

  // ── Public Getters ──
  bool get isMonitoring => _isMonitoring;
  double get threshold => _threshold;
  double get currentDecibel => _currentDecibel;

  // ── Value Notifiers ──
  final ValueNotifier<bool> monitoringNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<double> decibelNotifier = ValueNotifier<double>(0.0);

  /// Initialize the service by loading settings from SharedPreferences
  /// and auto-resuming if it was previously enabled.
  Future<void> init() async {
    await _loadSettings();
    // Auto-start if it was enabled before
    if (_isMonitoring) {
      Future.delayed(const Duration(milliseconds: 500), () {
        startMonitoring();
      });
    }
  }

  /// Load saved settings only — NO permission requests, NO auto-start.
  /// Safe to call on app startup.
  Future<void> loadSettingsOnly() async {
    await _loadSettings();
    debugPrint('[NoiseMonitor] Settings loaded (no permissions requested)');
  }

  /// Load settings from local storage
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isMonitoring = prefs.getBool('noise_monitor_enabled') ?? false;
      _threshold = prefs.getDouble('noise_monitor_threshold') ?? 85.0;
      debugPrint('[NoiseMonitor] Settings loaded: enabled=$_isMonitoring, threshold=$_threshold dB');
    } catch (e) {
      debugPrint('[NoiseMonitor] Error loading settings: $e');
    }
  }

  /// Start monitoring noise levels
  Future<bool> startMonitoring() async {
    if (_noiseSubscription != null) return true;

    try {
      // 1. Request microphone permission
      final status = await Permission.microphone.status;
      if (!status.isGranted) {
        final requestStatus = await Permission.microphone.request();
        if (!requestStatus.isGranted) {
          debugPrint('[NoiseMonitor] Microphone permission denied');
          _isMonitoring = false;
          monitoringNotifier.value = false;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('noise_monitor_enabled', false);
          return false;
        }
      }

      // 2. Initialize NoiseMeter
      _noiseMeter ??= NoiseMeter();
      _consecutiveLoudReadings = 0;

      // 3. Listen to stream
      _noiseSubscription = _noiseMeter!.noise.listen(
        (NoiseReading noiseReading) {
          _currentDecibel = noiseReading.maxDecibel;
          decibelNotifier.value = _currentDecibel;

          // Check if decibels exceed threshold
          if (_currentDecibel >= _threshold) {
            _consecutiveLoudReadings++;
            debugPrint('[NoiseMonitor] Loud noise detected! Level: ${_currentDecibel.toStringAsFixed(1)} dB (Count: $_consecutiveLoudReadings)');
            
            // Require 3 consecutive readings (approx. 1 second of sustained noise) to trigger SOS
            if (_consecutiveLoudReadings >= 3) {
              debugPrint('[NoiseMonitor] 🚨 SUSTAINED LOUD NOISE DETECTED! Triggering SOS...');
              _triggerSOS();
            }
          } else {
            // Reset consecutive count if it falls below threshold
            if (_consecutiveLoudReadings > 0) {
              _consecutiveLoudReadings = 0;
            }
          }
        },
        onError: (Object error) {
          debugPrint('[NoiseMonitor] Stream error: $error');
          stopMonitoring();
        },
        cancelOnError: true,
      );

      _isMonitoring = true;
      monitoringNotifier.value = true;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('noise_monitor_enabled', true);
      
      debugPrint('[NoiseMonitor] ✅ Monitoring started (Threshold: $_threshold dB)');
      return true;
    } catch (e) {
      debugPrint('[NoiseMonitor] Failed to start monitoring: $e');
      _isMonitoring = false;
      monitoringNotifier.value = false;
      return false;
    }
  }

  /// Stop monitoring noise levels
  Future<void> stopMonitoring() async {
    if (_noiseSubscription == null) return;

    try {
      await _noiseSubscription!.cancel();
      _noiseSubscription = null;
      _isMonitoring = false;
      _currentDecibel = 0.0;
      _consecutiveLoudReadings = 0;
      
      monitoringNotifier.value = false;
      decibelNotifier.value = 0.0;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('noise_monitor_enabled', false);

      debugPrint('[NoiseMonitor] ⛔ Monitoring stopped');
    } catch (e) {
      debugPrint('[NoiseMonitor] Error stopping monitoring: $e');
    }
  }

  /// Update the trigger threshold
  Future<void> setThreshold(double value) async {
    _threshold = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('noise_monitor_threshold', value);
      debugPrint('[NoiseMonitor] Threshold updated to: $value dB');
    } catch (e) {
      debugPrint('[NoiseMonitor] Error saving threshold: $e');
    }
  }

  /// Trigger SOS flow and navigate to EmergencyScreen
  void _triggerSOS() {
    if (navigatorKey?.currentState != null) {
      stopMonitoring(); // Stop monitoring during emergency countdown
      
      navigatorKey!.currentState!.push(
        MaterialPageRoute(builder: (context) => const EmergencyScreen()),
      );
    } else {
      debugPrint('[NoiseMonitor] ⚠️ Navigator key not available — cannot trigger SOS');
    }
  }
}
