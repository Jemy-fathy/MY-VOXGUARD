import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'voxguard_emergency',
      initialNotificationTitle: 'VoxGuard Active',
      initialNotificationContent: 'Protection running in background',
      foregroundServiceTypes: [
        AndroidForegroundType.location,
        AndroidForegroundType.microphone,
      ],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
    ),
  );
  
  await service.startService();
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
  }

  // تعريف المتغيرات في الأعلى لتكون متاحة داخل الـ Listeners
  final AudioRecorder audioRecorder = AudioRecorder();
  StreamSubscription<Position>? locationSub;

  // الاستماع للأحداث (SOS)
  service.on("startSOS").listen((event) async {
    if (event == null) return;

    final sosId = event["sos_id"];
    final token = event["token"];
    final bool recordAudio = event["record_audio"] ?? false;

    debugPrint("📡 [Background Service] Received SOS signal for ID: $sosId");

    if (recordAudio) {
      try {
        final dir = await getTemporaryDirectory();
        final String path = '${dir.path}/permanent_bg_audio.wav';
        
        // تأكد أن التسجيل قد توقف قبل الرفع لضمان حفظ الملف
        if (await audioRecorder.isRecording()) {
          await audioRecorder.stop();
        }

        var request = http.MultipartRequest(
          'POST', 
          Uri.parse("http://192.168.1.191:8000/api/sos/$sosId/uploadAudio")
        );
        request.headers['Authorization'] = 'Bearer $token';
        request.files.add(await http.MultipartFile.fromPath('audio_file', path));

        var response = await request.send();
        
        if (response.statusCode == 200) {
          debugPrint("✅ Audio uploaded successfully!");
        } else {
          debugPrint("❌ Failed to upload audio: ${response.statusCode}");
        }
      } catch (e) {
        debugPrint("❌ Error during background upload: $e");
      }
    }
  });

  // تحديث الموقع (يجب تعريف locationSub فوق إذا أردت إلغاءه)
  locationSub = Geolocator.getPositionStream(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
  ).listen((pos) {
    debugPrint("Location updated: ${pos.latitude}, ${pos.longitude}");
    // ملاحظة: يمكنك إضافة هنا إرسال الموقع للسيرفر دورياً إذا أردت
  });

  // إيقاف الخدمة
  service.on('stopService').listen((event) async {
    locationSub?.cancel();
    if (await audioRecorder.isRecording()) {
      await audioRecorder.stop();
    }
    await audioRecorder.dispose();
    service.stopSelf();
  });
}