import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/api_config.dart';

/// An active emergency session, returned by the backend when an SOS is opened.
@immutable
class SosSession {
  const SosSession({
    required this.sosId,
    required this.token,
    this.isMock = false,
  });

  final int sosId;
  final String token;

  /// `true` when the backend was unreachable and this session is a local
  /// stand-in, so the SOS flow still works end-to-end (demo / offline).
  /// Mock sessions always carry a negative [sosId].
  final bool isMock;
}

/// Owns the lifecycle of an SOS alert, with no UI dependencies so it can be
/// shared by both the manual flow ([EmergencyScreen]) and the AI
/// auto-detection flow.
///
/// Responsibilities:
///  * [startSession]        – open a session on the server with the current GPS.
///  * [startBackgroundGuard]– launch the foreground service (live location +
///                            audio recording) that survives the screen going off.
///  * [cancelSession]       – close a session that was aborted during the
///                            cancel grace period.
class SosService {
  const SosService();

  static const Duration _locationTimeout = Duration(seconds: 5);
  static const Duration _requestTimeout = Duration(seconds: 8);

  /// SharedPreferences keys shared with [SafeHomeScreen] and the map flow.
  static const String prefsSosId = 'current_sos_id';
  static const String prefsIsMock = 'sos_is_mock';

  /// Opens a new SOS session on the backend.
  ///
  /// Captures the current location (falling back to the last known position,
  /// then to `0.0, 0.0`) and posts it to `/sos/start`. On success returns the
  /// created [SosSession].
  ///
  /// If the backend is unreachable (e.g. the local host at [ApiConfig.baseUrl]
  /// is not running) — or the device is unauthenticated — this falls back to a
  /// **mock session** instead of failing, so the SOS feature still works
  /// end-to-end for demos and offline testing. Mock sessions are flagged via
  /// [SosSession.isMock] and a negative `sosId`.
  Future<SosSession?> startSession({required String triggerType}) async {
    final token = await _readToken();
    final position = await _currentPosition();

    // No credentials at all → go straight to a mock session rather than
    // blocking the whole emergency flow.
    if (token == null) {
      debugPrint('SosService: no auth token, starting MOCK SOS session.');
      return _mockSession(token: 'mock-token');
    }

    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.sosBaseUrl}/start'),
            headers: _jsonHeaders(token),
            body: jsonEncode({
              'latitude': position?.latitude.toString() ?? '0.0',
              'longitude': position?.longitude.toString() ?? '0.0',
              'trigger_type': triggerType,
            }),
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final sosId = data['sos_id'] as int;

        // Persist so SafeHomeScreen / the background service can recover the
        // active session id if they are reached without it.
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(prefsSosId, sosId);
        await prefs.setBool(prefsIsMock, false);

        return SosSession(sosId: sosId, token: token);
      }

      debugPrint('SosService: start failed '
          '(${response.statusCode}) ${response.body}');
    } catch (e) {
      debugPrint('SosService: start error $e');
    }

    // Backend unreachable / rejected → fall back to a mock session so the alert
    // still activates locally instead of dead-ending on an error screen.
    debugPrint('SosService: backend unavailable, starting MOCK SOS session.');
    return _mockSession(token: token);
  }

  /// Builds a local stand-in session and persists it like a real one so the
  /// background guard and [SafeHomeScreen] behave identically.
  Future<SosSession> _mockSession({required String token}) async {
    // Negative id => unmistakably mock; never collides with backend ids.
    final mockId = -(DateTime.now().millisecondsSinceEpoch ~/ 1000);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(prefsSosId, mockId);
    await prefs.setBool(prefsIsMock, true);

    return SosSession(sosId: mockId, token: token, isMock: true);
  }

  /// Starts the foreground background service and hands it the session so it
  /// can stream live location and record audio while the screen is off.
  Future<void> startBackgroundGuard({
    required SosSession session,
    required bool shareLocation,
    required bool recordAudio,
  }) async {
    try {
      // Audio recording needs RECORD_AUDIO granted in the FOREGROUND: the
      // background isolate can't show a permission prompt, so resolve it here
      // and downgrade to no-audio if the mic isn't available.
      bool canRecordAudio = recordAudio;
      if (recordAudio) {
        canRecordAudio = (await Permission.microphone.request()).isGranted;
      }

      final service = FlutterBackgroundService();
      await service.startService();

      // Give the isolate a moment to spin up before delivering the payload.
      await Future<void>.delayed(const Duration(milliseconds: 800));

      service.invoke('startSOS', {
        'sos_id': session.sosId,
        'token': session.token,
        'share_location': shareLocation,
        'record_audio': canRecordAudio,
      });
    } catch (e) {
      debugPrint('SosService: background guard error $e');
    }
  }

  /// Best-effort close of a session the user cancelled during the countdown.
  /// Failures are swallowed since the alert never really started.
  Future<void> cancelSession(SosSession session) async {
    await _clearMockFlag();

    // A mock session never reached the server, so there is nothing to close.
    if (session.isMock) return;

    try {
      await http
          .post(
            Uri.parse('${ApiConfig.sosBaseUrl}/${session.sosId}/safe'),
            headers: {
              'Authorization': 'Bearer ${session.token}',
              'Accept': 'application/json',
            },
          )
          .timeout(_requestTimeout);
    } catch (e) {
      debugPrint('SosService: cancel error $e');
    }
  }

  Future<void> _clearMockFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsIsMock);
  }

  // --- helpers -------------------------------------------------------------

  Future<String?> _readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? prefs.getString('auth_token');
  }

  /// Best available position: a fresh high-accuracy fix, else the last known
  /// one, else `null` (e.g. permission denied or location services off).
  Future<Position?> _currentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: _locationTimeout,
      );
    } catch (_) {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  Map<String, String> _jsonHeaders(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
}
