import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:vox_guard/screens/sos/background_service.dart'; 
import '../../config/api_config.dart';

const Duration kListenWindow = Duration(seconds: 12);
const Duration kAiChunkDuration = Duration(minutes: 2);
const String kSosActiveKey = 'sos_active';
const String kAiAutoModeKey = 'ai_auto_mode_enabled';
const String kEmotionDetectionKey = 'emotion_detection_enabled';
const String _kCustomZonesKey = 'user_custom_zones_local';


Future<bool> screenForDanger(String filePath,
    {required String locationText}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('auth_token');

    final sttReq = http.MultipartRequest('POST', Uri.parse(ApiConfig.sttUrl));
    sttReq.files.add(await http.MultipartFile.fromPath('audio', filePath));
    final sttResp = await http.Response.fromStream(await sttReq.send());

    debugPrint(
        '[AI-MONITOR] STT Response: ${sttResp.statusCode} | ${sttResp.body}');

    final String text = jsonDecode(sttResp.body)['text']?.toString() ?? '';
    if (text.isEmpty || text == 'null') return false;

    final dangerResp = await http.post(
      Uri.parse(ApiConfig.dictionaryCheckUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: {
        'text': text,
        'location_text': locationText,
        'latitude': '0',
        'longitude': '0'
      },
    );

    debugPrint(
        '[AI-MONITOR] Dictionary Check Response: ${dangerResp.statusCode} | ${dangerResp.body}');

    final data = jsonDecode(dangerResp.body);
    return dangerResp.statusCode == 200 && data['danger_detected'] == true;
  } catch (e) {
    debugPrint('[AI-MONITOR] Dictionary Check Error: $e');
    return false;
  }
}


Future<bool> isInsideSafeZone(double lat, double lng) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final List<String> raw = prefs.getStringList(_kCustomZonesKey) ?? const [];
    for (final entry in raw) {
      final Map<String, dynamic> z = jsonDecode(entry) as Map<String, dynamic>;
      if (z['isDanger'] == true) continue;
      
      final double zlat = (z['lat'] as num).toDouble();
      final double zlng = (z['lng'] as num).toDouble();
      final double radius = (z['radius'] as num).toDouble();

      if (Geolocator.distanceBetween(lat, lng, zlat, zlng) <= radius) {
        return true;
      }
    }
  } catch (e) {
    debugPrint('[AI-MONITOR] safe-zone check error: $e');
  }
  return false;
}

Future<void> checkDangerZoneStatus(Position pos) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload(); 
  
  bool isSosActive = prefs.getBool('sos_active') ?? false;
  if (isSosActive) {
    debugPrint('[AI-MONITOR] SOS is already active. Skipping Danger Zone check.');
    return;
  }
  
  List<String> zones = prefs.getStringList('user_custom_zones_local') ?? [];

  for (var zoneStr in zones) {
    Map<String, dynamic> zone = jsonDecode(zoneStr);
    
    double distance = Geolocator.distanceBetween(
        pos.latitude, pos.longitude, zone['lat'], zone['lng']);

    if (distance <= zone['radius']) {
      if (zone['isDanger'] == true && zone['notify_contacts'] == true) {
                await triggerSos(
          isManual: false, 
          reason: "Danger Zone: ${zone['name']}"
        );
        return; 
      }
    }
  }
}
Future<void> uploadRecordingToBackend(String filePath, {int? sosId}) async {
  try {
    if (!await File(filePath).exists()) return;

    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString('auth_token');


    final uri = (sosId != null && sosId > 0)
        ? Uri.parse('${ApiConfig.sosBaseUrl}/$sosId/uploadAudio')
        : Uri.parse(ApiConfig.monitorAudioUrl);

    final req = http.MultipartRequest('POST', uri);
    if (token != null) req.headers['Authorization'] = 'Bearer $token';

    req.files.add(await http.MultipartFile.fromPath(
        (sosId != null && sosId > 0) ? 'audio_file' : 'audio', filePath));
    final response = await req.send().timeout(const Duration(seconds: 45));

    if (response.statusCode == 200) {
      debugPrint('[AI-MONITOR] Evidence uploaded successfully');
    }
  } catch (e) {
    debugPrint('[AI-MONITOR] Upload error: $e');
  }
}
Future<String?> confirmEmotion(String filePath) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final String userId = prefs.getString('user_id') ?? '0';

    final emoReq =
        http.MultipartRequest('POST', Uri.parse(ApiConfig.emotionUrl));
    emoReq.files.add(await http.MultipartFile.fromPath('file', filePath));
    emoReq.fields['user_id'] = userId;

    final emoResp = await http.Response.fromStream(await emoReq.send());

    debugPrint(
        '[AI-MONITOR] Emotion Model Response: ${emoResp.statusCode} | ${emoResp.body}');

    final data = jsonDecode(emoResp.body);
    
    if (data['trigger_sos'] == true) {
      return data['emotion']?.toString() ?? 'detected';
    }
    return null;
  } catch (e) {
    debugPrint('[AI-MONITOR] Emotion Model Error: $e');
    return null;
  }
}

Future<void> runAiMonitorLoop(ServiceInstance service) async {
  final recorder = AudioRecorder();
  final tempDir = await getTemporaryDirectory();

  while (true) {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
      
      bool isSafe = await isInsideSafeZone(pos.latitude, pos.longitude);
      if (isSafe) {
        debugPrint('[AI-MONITOR] User is in a Safe Zone. AI Monitor FORCED OFF.');
        await Future.delayed(const Duration(seconds: 30)); 
        continue;
      }

   
      await checkDangerZoneStatus(pos);

      bool isEmotionEnabled = prefs.getBool(kEmotionDetectionKey) ?? true;
      if (!isEmotionEnabled) {
        await Future.delayed(const Duration(seconds: 10));
        continue;
      }
      final String tempPath = '${tempDir.path}/quick_check.wav';
      
      await recorder.start(const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000), path: tempPath);
      await Future.delayed(const Duration(seconds: 10));
      await recorder.stop();

      // Transcribe recorded audio
      String transcribedText = '';
      try {
        final sttReq = http.MultipartRequest('POST', Uri.parse(ApiConfig.sttUrl));
        sttReq.files.add(await http.MultipartFile.fromPath('audio', tempPath));
        final sttResp = await http.Response.fromStream(await sttReq.send());
        if (sttResp.statusCode == 200) {
          transcribedText = jsonDecode(sttResp.body)['text']?.toString() ?? '';
        }
      } catch (e) {
        debugPrint('[AI-MONITOR] STT Error in Loop: $e');
      }

      if (transcribedText.isNotEmpty && transcribedText != 'null') {
        final String savedPhrase = prefs.getString('voice_phrase') ?? '';
        if (savedPhrase.isNotEmpty && transcribedText.toLowerCase().contains(savedPhrase.toLowerCase())) {
          debugPrint('[AI-MONITOR] 🚨 Voice phrase "$savedPhrase" detected! Waking screen and launching Emergency Screen...');
          
          final appDir = await getApplicationDocumentsDirectory();
          final String savedPath = '${appDir.path}/SOS_phrase_${DateTime.now().millisecondsSinceEpoch}.wav';
          await File(tempPath).copy(savedPath);

          if (Platform.isAndroid) {
            try {
              const panicChannel = MethodChannel('com.example.vox_guard/panic');
              await panicChannel.invokeMethod('showSosNotification');
            } catch (e) {
              debugPrint('Failed to show native SOS notification: $e');
            }
          }
          
          if (await File(tempPath).exists()) await File(tempPath).delete();
          continue;
        }

        // Fallback to regular dictionary check if voice phrase not found
        bool isDanger = false;
        try {
          final String? token = prefs.getString('auth_token');
          final dangerResp = await http.post(
            Uri.parse(ApiConfig.dictionaryCheckUrl),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/x-www-form-urlencoded'
            },
            body: {
              'text': transcribedText,
              'location_text': "${pos.latitude},${pos.longitude}",
              'latitude': '0',
              'longitude': '0'
            },
          );
          final data = jsonDecode(dangerResp.body);
          isDanger = dangerResp.statusCode == 200 && data['danger_detected'] == true;
        } catch (e) {
          debugPrint('[AI-MONITOR] Dictionary check error: $e');
        }

        if (isDanger) {
          final String fullRecordPath = '${tempDir.path}/evidence_full.wav';
          await recorder.start(const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000), path: fullRecordPath);
          await Future.delayed(const Duration(minutes: 1)); 
          await recorder.stop();

          String? emotionResult = await confirmEmotion(fullRecordPath);

          if (emotionResult != null) {
            final appDir = await getApplicationDocumentsDirectory();
            final String savedPath = '${appDir.path}/SOS_${DateTime.now().millisecondsSinceEpoch}.wav';
            await File(fullRecordPath).copy(savedPath);

            await triggerSos(
              isManual: false,
              reason: "AI Detected Danger: $emotionResult", 
              emotion: emotionResult, 
              evidencePath: savedPath,
            );
          }
        }
      }
      
      if (await File(tempPath).exists()) await File(tempPath).delete();

    } catch (e) {
      debugPrint('>>> [BACKGROUND SERVICE] Error in Loop: $e');
      await Future.delayed(const Duration(seconds: 3)); 
    }
  }
}