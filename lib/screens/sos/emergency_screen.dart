import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'home_screen.dart';
import '../../../config/colors.dart';
import '../../../custom_widgets/custom_button.dart';
import 'safe_home_screen.dart';
import 'package:flutter_background_service/flutter_background_service.dart'; 

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  int _start = 3;
  Timer? _timer;
  bool _isLocationSharing = true;
  bool _isAudioRecording = true;
  bool _isLoading = false;
  bool _isCancelled = false; 

  final String baseUrl = "http://192.168.1.191:8000/api/sos";

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_start <= 1) {
        _timer?.cancel();

        setState(() {
          _start = 0;
          _isLoading = true;
        });
        final Map<String, dynamic>? sosSessionData = await _executeSOSLogic();

        if (!mounted || _isCancelled) {
          _cleanUpAndStopServiceIfNeeded(sosSessionData?['sos_id'], sosSessionData?['token']);
          return;
        }
        if (sosSessionData != null) {
          _startBackgroundSecurityService(sosSessionData['sos_id'], sosSessionData['token']);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SafeHomeScreen(
                sosId: sosSessionData['sos_id'],
                token: sosSessionData['token'],
                isLocationSharing: _isLocationSharing,
                isAudioRecording: _isAudioRecording,
              ),
            ),
          );
        } else {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Connection failed. Please try again.')),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      } else {
        setState(() => _start--);
      }
    });
  }

  // ... (الـ imports الخاصة بك كما هي)

Future<Map<String, dynamic>?> _executeSOSLogic() async {
  final prefs = await SharedPreferences.getInstance();
  final String? token = prefs.getString('token') ?? prefs.getString('auth_token');

  try {
    // 1. محاولة الحصول على الموقع
    Position? position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 5),
    ).catchError((e) => Geolocator.getLastKnownPosition());

    // 2. إرسال الطلب للسيرفر
    final response = await http.post(
      Uri.parse('$baseUrl/start'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'latitude': position?.latitude.toString() ?? '0.0',
        'longitude': position?.longitude.toString() ?? '0.0',
        'trigger_type': 'manual',
      }),
    );

    // 3. كشف سبب الفشل إذا حدث
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      await prefs.setInt('current_sos_id', data['sos_id']);
      return {'sos_id': data['sos_id'], 'token': token};
    } else {
      debugPrint("❌ Server Error: ${response.statusCode} - ${response.body}");
    }
  } catch (e) {
    debugPrint("❌ Exception: $e");
  }
  return null;
}  
  void _startBackgroundSecurityService(int sosId, String token) async {
    try {
      final service = FlutterBackgroundService();
      
      bool isStarted = await service.startService();
      print("📡 [Service] startService invoked, status: $isStarted");

      await Future.delayed(const Duration(milliseconds: 800));

      service.invoke("startSOS", {
        "sos_id": sosId,
        "token": token,
        "share_location": _isLocationSharing,
        "record_audio": _isAudioRecording
      });
      
      debugPrint("🚀 VoxGuard Background Security Service Configured & Payload Sent for SOS ID: $sosId");
    } catch (e) {
      debugPrint("Error starting background service: $e");
    }
  }

  // 🌟 دالة لتنظيف الجلسة برمجياً إذا تم إلغاء الطوارئ في نفس ثانية استجابة السيرفر
  void _cleanUpAndStopServiceIfNeeded(int? sosId, String? token) async {
    if (sosId != null && token != null) {
      try {
        // إعلام السيرفر بإغلاق هذه الجلسة فوراً لأنها ألغيت
        await http.post(
          Uri.parse("$baseUrl/$sosId/safe"),
          headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
        );
      } catch (e) {
        debugPrint("Error cleaning up cancelled remote session: $e");
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgBlueLight, AppColors.bgPurpleLight, Colors.white],
            stops: [0.0, 0.3, 0.7],
          ),
        ),
        child: Column(
          children: [
            const Spacer(flex: 3),
            _isLoading
                ? const CircularProgressIndicator(color: AppColors.primaryPurple)
                : Text('$_start', style: const TextStyle(fontSize: 180, fontWeight: FontWeight.w900, color: AppColors.primaryPurple)),
            const SizedBox(height: 10),
            const Text('SOS Mode Activated', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.primaryPurple)),
            const SizedBox(height: 8),
            const Text('Sending Alerts to Emergency Contacts', style: TextStyle(fontSize: 16, color: Colors.black45)),
            const Spacer(),
            _buildActionCard(Icons.location_on, 'Share live Location', _isLocationSharing, (val) => setState(() => _isLocationSharing = val)),
            const SizedBox(height: 16),
            _buildActionCard(Icons.mic_rounded, 'Recording Audio', _isAudioRecording, (val) => setState(() => _isAudioRecording = val)),
            const Spacer(flex: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
              child: CustomButton(
                text: 'Cancel SOS',
                onPressed: () {
                  _timer?.cancel();
                  setState(() => _isCancelled = true); // رفع علم الإلغاء فوراً
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(IconData icon, String title, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 25),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(40), 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8), 
            decoration: BoxDecoration(color: AppColors.primaryPurple.withOpacity(0.1), shape: BoxShape.circle), 
            child: Icon(icon, color: AppColors.primaryPurple, size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
          Switch(value: value, onChanged: onChanged, activeTrackColor: AppColors.primaryPurple),
        ],
      ),
    );
  }
}