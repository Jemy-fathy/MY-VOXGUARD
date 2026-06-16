import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/api_config.dart';

/// Length of each monitoring audio chunk: the recorder captures this much audio
/// before it is handed to the AI pipeline and uploaded to the backend.
const Duration kAiChunkDuration = Duration(minutes: 2);

/// SharedPreferences flag set by the background service while an SOS is active.
/// The foreground monitor checks it and steps aside so the two isolates never
/// fight over the microphone.
const String kSosActiveKey = 'sos_active';

/// Runs the AI pipeline on a recorded chunk: speech-to-text → backend danger
/// check → emotion analysis. Returns true when the analysis recommends
/// triggering an emergency SOS.
///
/// Safe to call from any isolate (the foreground UI or the background service).
Future<bool> analyzeAudioChunk(
  String filePath, {
  required String locationText,
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('auth_token');
    final String userId = prefs.getString('user_id') ?? '0';

    // 1) Speech-to-text.
    final sttReq = http.MultipartRequest('POST', Uri.parse(ApiConfig.sttUrl));
    sttReq.files.add(await http.MultipartFile.fromPath('audio', filePath));
    final sttResp = await http.Response.fromStream(await sttReq.send());
    final String text = jsonDecode(sttResp.body)['text']?.toString() ?? 'nothing';
    if (text == 'nothing' || text == 'null' || text.trim().isEmpty) {
      return false;
    }

    // 2) Danger-word check (backend dictionary).
    final dangerResp = await http.post(
      Uri.parse(ApiConfig.dictionaryCheckUrl),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      body: {'text': text, 'location_text': locationText},
    );
    if (dangerResp.statusCode != 200 ||
        jsonDecode(dangerResp.body)['danger_detected'] != true) {
      return false;
    }

    // 3) Emotion / voice-stress analysis.
    final emoReq = http.MultipartRequest('POST', Uri.parse(ApiConfig.emotionUrl));
    emoReq.files.add(await http.MultipartFile.fromPath('file', filePath));
    emoReq.fields['user_id'] = userId;
    final emoResp = await http.Response.fromStream(await emoReq.send());
    return jsonDecode(emoResp.body)['trigger_sos'] == true;
  } catch (e) {
    debugPrint('[AI-MONITOR] analyze error: $e');
    return false;
  }
}

/// Best-effort upload of a monitoring recording to the backend so the audio is
/// stored as evidence. During an active SOS ([sosId] > 0) it attaches to that
/// session's `uploadAudio` endpoint; otherwise it posts to the general monitor
/// endpoint. Failures are swallowed so monitoring never breaks.
Future<void> uploadRecordingToBackend(
  String filePath, {
  int? sosId,
  String? token,
}) async {
  try {
    if (!await File(filePath).exists()) return;

    final prefs = await SharedPreferences.getInstance();
    token ??= prefs.getString('auth_token');

    final bool hasSos = sosId != null && sosId > 0;
    final Uri uri = hasSos
        ? Uri.parse('${ApiConfig.sosBaseUrl}/$sosId/uploadAudio')
        : Uri.parse(ApiConfig.monitorAudioUrl);

    final req = http.MultipartRequest('POST', uri);
    if (token != null && token.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $token';
    }
    req.files.add(
      await http.MultipartFile.fromPath(hasSos ? 'audio_file' : 'audio', filePath),
    );
    final resp = await req.send().timeout(const Duration(seconds: 30));
    debugPrint('[AI-MONITOR] recording uploaded (${resp.statusCode}) → $uri');
  } catch (e) {
    debugPrint('[AI-MONITOR] recording upload failed: $e');
  }
}
