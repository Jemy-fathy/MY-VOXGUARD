import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'voice_monitor_service.dart';
import 'noise_monitor_service.dart';

/// Coordinates VoiceMonitorService and NoiseMonitorService based on Safe Zone.
/// - Inside Safe Zone: All monitors disabled (privacy + battery)
/// - Outside Safe Zone: VoiceMonitor always ON, NoiseMonitor ON if enabled
class ContextAwareMonitorService {
  static final ContextAwareMonitorService _instance = ContextAwareMonitorService._internal();
  factory ContextAwareMonitorService() => _instance;
  ContextAwareMonitorService._internal();

  bool _isInSafeZone = false;
  bool _isActive = false;

  StreamSubscription<Position>? _positionSubscription;

  final ValueNotifier<bool> safeZoneNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String> stateNotifier = ValueNotifier<String>('Idle');

  bool get isInSafeZone => _isInSafeZone;
  String get currentState => stateNotifier.value;

  Future<void> init() async {
    debugPrint('[ContextAware] Initializing...');

    // Wait for the first frame before requesting location (avoids permission clash)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _startLocationStream();
    });

    VoiceMonitorService().monitoringNotifier.addListener(_onSettingsChanged);
    NoiseMonitorService().monitoringNotifier.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    _startLocationStream();
    _evaluateState();
  }

  void onSettingsChanged() {
    _onSettingsChanged();
  }

  Future<void> _startLocationStream() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        if (_positionSubscription == null) {
          const LocationSettings locationSettings = LocationSettings(
            accuracy: LocationAccuracy.medium,
            distanceFilter: 50,
          );

          _positionSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
            (Position position) => _evaluateLocation(position),
            onError: (err) {
              debugPrint('[ContextAware] Location stream error: $err');
              _evaluateLocation(null);
            },
          );
        }

        try {
          final lastKnown = await Geolocator.getLastKnownPosition();
          if (lastKnown != null) {
            _evaluateLocation(lastKnown);
          } else {
            final current = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
            _evaluateLocation(current);
          }
        } catch (e) {
          debugPrint('[ContextAware] Error getting position: $e');
          _evaluateLocation(null);
        }
      } else {
        debugPrint('[ContextAware] Location denied — defaulting to outside Safe Zone');
        _positionSubscription?.cancel();
        _positionSubscription = null;
        _evaluateLocation(null);
      }
    } catch (e) {
      debugPrint('[ContextAware] Location error: $e');
      _positionSubscription?.cancel();
      _positionSubscription = null;
      _evaluateLocation(null);
    }
  }

  Future<void> _evaluateLocation(Position? position) async {
    if (position == null) {
      _setSafeZone(false);
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final placesJson = prefs.getString('safePlaces');
      final circlesJson = prefs.getString('saved_zones');

      Map<String, dynamic> safePlaces = {};
      List<dynamic> savedCircles = [];
      if (placesJson != null) safePlaces = json.decode(placesJson);
      if (circlesJson != null) savedCircles = json.decode(circlesJson);

      bool found = false;

      for (var entry in safePlaces.entries) {
        final val = entry.value;
        if (val['lat'] != null && val['lng'] != null) {
          double distance = Geolocator.distanceBetween(
            position.latitude, position.longitude, val['lat'], val['lng'],
          );
          if (distance <= 100.0) {
            debugPrint('[ContextAware] In Safe Place: ${entry.key}');
            found = true;
            break;
          }
        }
      }

      if (!found) {
        for (var c in savedCircles) {
          if (c['type'] == 'safe' && c['lat'] != null && c['lng'] != null) {
            double distance = Geolocator.distanceBetween(
              position.latitude, position.longitude, c['lat'], c['lng'],
            );
            if (distance <= (c['radius'] ?? 100.0)) {
              found = true;
              break;
            }
          }
        }
      }

      _setSafeZone(found);
    } catch (e) {
      _setSafeZone(false);
    }
  }

  void _setSafeZone(bool inSafeZone) {
    if (_isInSafeZone == inSafeZone) return;
    _isInSafeZone = inSafeZone;
    safeZoneNotifier.value = inSafeZone;
    debugPrint('[ContextAware] Safe Zone: $inSafeZone');
    _evaluateState();
  }

  Future<void> _evaluateState() async {
    final prefs = await SharedPreferences.getInstance();
    final bool noiseEnabled = prefs.getBool('noise_monitor_enabled') ?? false;
    final String phrase = prefs.getString('voice_phrase') ?? '';
    final bool voiceEnabled = phrase.isNotEmpty;

    if (!voiceEnabled && !noiseEnabled) {
      _stopAll();
      stateNotifier.value = 'Idle';
      return;
    }

    if (_isInSafeZone) {
      _stopAll();
      stateNotifier.value = 'SafeZone';
      debugPrint('[ContextAware] Safe Zone — monitors disabled');
      return;
    }

    // Outside Safe Zone — activate monitors
    // VoiceMonitor has microphone priority. NoiseMonitor only runs if VoiceMonitor is OFF.
    if (voiceEnabled) {
      if (VoiceMonitorService().isSosTriggered) {
        debugPrint('[ContextAware] ⏭️ SOS active — not restarting VoiceMonitor');
      } else {
        await VoiceMonitorService().startMonitoring();
        debugPrint('[ContextAware] VoiceMonitor ON (mic in use) — NoiseMonitor OFF');
      }
    } else if (noiseEnabled) {
      await NoiseMonitorService().startMonitoring();
      debugPrint('[ContextAware] NoiseMonitor ON (no voice phrase)');
    }

    _isActive = true;
    stateNotifier.value = 'Active';
  }

  void _stopAll() {
    _isActive = false;
    VoiceMonitorService().stopMonitoring();
    NoiseMonitorService().stopMonitoring();
  }

  void dispose() {
    _stopAll();
    _positionSubscription?.cancel();
  }
}
