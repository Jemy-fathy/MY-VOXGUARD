import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized API endpoints for the VoxGuard backend and AI microservices.
class ApiConfig {
  const ApiConfig._();

  // ⚠️ استخدم IP الشبكة المحلية للـ Mac (مش 127.0.0.1) عشان الجهاز الحقيقي يوصل للسيرفر
  // شغّل: ipconfig getifaddr en0  لو الـ IP اتغيّر
  static String _serverIp = "192.168.1.29"; // Fallback default Mac IP
  static String get serverIp => _serverIp;

  static void setServerIp(String ip) {
    _serverIp = ip;
  }

  /// Auto-discover the Laravel backend server on the local network subnet.
  static Future<String?> autoDiscoverServer() async {
    // 1. Try saved custom IP first
    try {
      final prefs = await SharedPreferences.getInstance();
      String savedIp = prefs.getString('custom_server_ip') ?? "";
      if (savedIp.isNotEmpty) {
        final client = HttpClient();
        client.connectionTimeout = const Duration(milliseconds: 250);
        final request = await client.getUrl(Uri.parse("http://$savedIp:8000/"));
        final response = await request.close();
        if (response.statusCode >= 200) {
          _serverIp = savedIp;
          return savedIp;
        }
      }
    } catch (_) {}

    // 2. Try emulator loopback (10.0.2.2)
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(milliseconds: 250);
      final request = await client.getUrl(Uri.parse("http://10.0.2.2:8000/"));
      final response = await request.close();
      if (response.statusCode >= 200) {
        _serverIp = "10.0.2.2";
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('custom_server_ip', "10.0.2.2");
        return "10.0.2.2";
      }
    } catch (_) {}

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(milliseconds: 300);
      final request = await client.getUrl(Uri.parse("http://192.168.1.29:8000/"));
      final response = await request.close();
      if (response.statusCode >= 200) {
        _serverIp = "192.168.1.29";
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('custom_server_ip', "192.168.1.29");
        return "192.168.1.29";
      }
    } catch (_) {}

    // 4. Scan active subnets
    try {
      List<NetworkInterface> interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      List<String> subnets = [];
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          String ip = addr.address;
          if (ip.startsWith("127.") || ip.startsWith("169.254.")) continue;
          
          List<String> parts = ip.split('.');
          if (parts.length == 4) {
            subnets.add("${parts[0]}.${parts[1]}.${parts[2]}");
          }
        }
      }

      String? foundIp;
      for (String subnet in subnets) {
        List<Future<void>> tasks = [];
        final client = HttpClient();
        client.connectionTimeout = const Duration(milliseconds: 150);

        for (int i = 2; i <= 254; i++) {
          final targetIp = "$subnet.$i";
          if (targetIp == "192.168.1.29" || targetIp == "10.0.2.2") continue;

          tasks.add(
            client.getUrl(Uri.parse("http://$targetIp:8000/"))
              .then((request) => request.close())
              .then((response) {
                if (response.statusCode >= 200) {
                  foundIp = targetIp;
                }
              })
              .catchError((_) {})
          );
          
          if (tasks.length >= 45) {
            await Future.wait(tasks);
            if (foundIp != null) break;
            tasks.clear();
          }
        }
        if (tasks.isNotEmpty) {
          await Future.wait(tasks);
        }
        if (foundIp != null) {
          _serverIp = foundIp!;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('custom_server_ip', foundIp!);
          return foundIp;
        }
      }
    } catch (_) {}

    return null;
  }

  static String get _backendHost => "http://$_serverIp:8000";
  static String get _sttHost => "http://$_serverIp:8003";
  static String get _emotionHost => "http://$_serverIp:8001";
  static String get aiBaseUrl => "http://$_serverIp:9000";

  // --- Endpoints ---
  static String get baseUrl => "$_backendHost/api";

  // Endpoints Laravel (Mohamed's)
  static String get login => "$baseUrl/login";
  static String get register => "$baseUrl/register";
  static String get forgotPassword => "$baseUrl/forgot-password";
  static String get resetPassword => "$baseUrl/reset-password";
  static String get updatePassword => "$baseUrl/settings/change-password";
  static String get settingsToggles => "$baseUrl/settings/toggles";
  static String get deleteAccount => "$baseUrl/settings/delete-account";
  static String get logout => "$baseUrl/settings/logout";
  static String get getProfile => "$baseUrl/profile";
  static String get updateProfile => "$baseUrl/profile/update";
  static String get scheduleFakeCall => "$baseUrl/fake-call/schedule";
  static String get activityLog => "$baseUrl/profile/activity-log";
  static String get updateEmergencyInfo =>
      "$baseUrl/profile/update-emergency-info";
  static String get createIncident => "$baseUrl/incidents/create";
  static String get incidentHistory => "$baseUrl/incidents/history";

  // Wearable Endpoints
  static String get updateHealth => "$baseUrl/wearable/update-health";

  // Endpoints AI (Mohamed's)
  static String get enroll => "$aiBaseUrl/enroll";
  static String get verify => "$aiBaseUrl/verify";
  static String get verifyUserId => "$aiBaseUrl/verify_user_id";
  static String get setupVoicePassword => "$baseUrl/voice-password/save";
  static String get verifyVoice => "$aiBaseUrl/verify_user_id";
  static String get checkVoiceMatch => "$aiBaseUrl/check-match";

  // Fake Call Voices
  static String get momVoice =>
      "$_backendHost/storage/recordings/mom_call.mp3";
  static String get dadVoice =>
      "$_backendHost/storage/recordings/dad_call.mp3";
  static String get policeVoice =>
      "$_backendHost/storage/recordings/police_call.mp3";

  // SOS / emergency endpoints (Abdelmonem's)
  static String get sosBaseUrl => '$baseUrl/sos';

  /// Speech-to-text service (Abdelmonem's)
  static String get sttUrl => '$_sttHost/transcribe';

  /// Emotion / voice-stress analysis service (Abdelmonem's)
  static String get emotionUrl => '$_emotionHost/analyze-smart/';

  /// Backend danger-word dictionary check (Abdelmonem's)
  static String get dictionaryCheckUrl => '$baseUrl/dictionary/check';

  /// Backend storage for periodic monitoring recordings (Abdelmonem's)
  static String get monitorAudioUrl => '$baseUrl/monitor/audio';
}
