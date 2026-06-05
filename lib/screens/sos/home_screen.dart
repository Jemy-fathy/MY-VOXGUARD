import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:record/record.dart'; 
import 'package:path_provider/path_provider.dart';
import 'dart:ui' as ui;
import 'emergency_screen.dart';
import '../fake_call/fake_call_screen.dart';
import '../map/map_screen.dart';
import '../profile/profile_screen.dart';
import '../reports/create_report_screen.dart';
import '../safety/trusted_contacts_screen.dart' show TrustedContactsScreen;
import '../voice_password/voice_password_intro_screen.dart';
import '../profile/settings_screen.dart'; 
import '../safety/start_trip_screen.dart'; 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _waveController;
  final AudioRecorder _audioRecorder = AudioRecorder();

  LatLng _currentLatLng = const LatLng(30.0444, 31.2357);
  String _locationText = "Locating...";
  late GoogleMapController _googleMapController;

  bool _isAiActive = true; 

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _determinePosition();

    // بدء عمليات الـ AI
    _startContinuousRecording();
    _runAILoop();
  }

  // --- كود الـ AI الجديد (الذي طلبتِ نسخه) ---
  Future<void> _startContinuousRecording() async {
    if (await _audioRecorder.hasPermission()) {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
        path: path,
      );
    }
  }

  Future<void> _runAILoop() async {
    while (_isAiActive && mounted) {
      if (_selectedIndex == 0) {
        await Future.delayed(const Duration(seconds: 10)); // التسجيل كل 10 ثوان
        final path = await _audioRecorder.stop();
        if (path != null) {
          await _processBuffer(path);
          final file = File(path);
          if (await file.exists()) await file.delete();
        }
        await _startContinuousRecording();
      } else {
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  Future<void> _processBuffer(String filePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');
      final String userId = prefs.getString('user_id') ?? "0";

      // 1. تحويل الصوت لنص
      var sttRequest = http.MultipartRequest('POST', Uri.parse("http://192.168.1.191:8003/transcribe"));
      sttRequest.files.add(await http.MultipartFile.fromPath('audio', filePath));
      var sttResponse = await sttRequest.send();
      var sttData = jsonDecode(await http.Response.fromStream(sttResponse).then((r) => r.body));
      String detectedText = sttData['text']?.toString() ?? "nothing";
      
      if (detectedText != "nothing" && detectedText != "null") {
        // 2. التحقق من الخطر
        var laravelResponse = await http.post(
          Uri.parse("http://192.168.1.191:8000/api/dictionary/check"),
          headers: {"Authorization": "Bearer $token", "Accept": "application/json"},
          body: {'text': detectedText, 'location_text': _locationText},
        );
        
        if (laravelResponse.statusCode == 200 && jsonDecode(laravelResponse.body)['danger_detected'] == true) {
          // 3. تحليل المشاعر
          var emotionRequest = http.MultipartRequest('POST', Uri.parse("http://192.168.1.191:8001/analyze-smart/"));
          emotionRequest.files.add(await http.MultipartFile.fromPath('file', filePath));
          emotionRequest.fields['user_id'] = userId;
          var emotionResponse = await emotionRequest.send();
          var emotionData = jsonDecode(await http.Response.fromStream(emotionResponse).then((r) => r.body));
          
          if (emotionData['trigger_sos'] == true) _triggerEmergencyAuto();
        }
      }
    } catch (e) { debugPrint("AI Error: $e"); }
  }

  void _triggerEmergencyAuto() {
    _isAiActive = false; 
    _audioRecorder.stop();
    Navigator.push(context, MaterialPageRoute(builder: (context) => const EmergencyScreen())).then((_) {
      _isAiActive = true;
      _startContinuousRecording();
      _runAILoop();
    });
  }

  // --- باقي الدوال والتصميم ---
  Future<Map<String, String>> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString('user_name') ?? "User",
      'image': prefs.getString('user_image') ?? "",
    };
  }

  Future<void> _determinePosition() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    Position position = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() => _currentLatLng = LatLng(position.latitude, position.longitude));
      _googleMapController.animateCamera(CameraUpdate.newLatLngZoom(_currentLatLng, 15));
      _getAddressFromLatLng(position.latitude, position.longitude);
    }
  }

  Future<void> _getAddressFromLatLng(double lat, double lon) async {
    final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1');
    try {
      final response = await http.get(url, headers: {'User-Agent': 'voxGuard', 'Accept-Language': 'en'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String displayName = data['display_name'] ?? "Unknown Location";
        List<String> parts = displayName.split(',');
        if (mounted) setState(() => _locationText = parts.length > 2 ? "${parts[0]}, ${parts[1]}" : displayName);
      }
    } catch (e) {
      if (mounted) setState(() => _locationText = "${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}");
    }
  }

  @override
  void dispose() {
    _isAiActive = false;
    _audioRecorder.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [ _buildHomeContent(), const TrustedContactsScreen(), const CreateReportScreen(), const SettingsScreen(), ];
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Color(0xFF8E9EFE), Color(0xFFD546F3)])),
        child: _selectedIndex == 0 ? _buildHomeContent() : pages[_selectedIndex],
      ),
      bottomNavigationBar: _bottomNav(),
    );
  }

  Widget _buildHomeContent() {
    return Column( 
      children: [
        const SizedBox(height: 40),
        _header(),
        const SizedBox(height: 30),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30))),
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 25), 
            child: ListView( 
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 5), 
                _sos(),
                const SizedBox(height: 25),
                _quickActions(),
                const SizedBox(height: 30),
                _safetyStatusCard(),
                const SizedBox(height: 25),
                _locationCard(),
                const SizedBox(height: 90), 
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: FutureBuilder<Map<String, String>>(
        future: _loadUserData(),
        builder: (context, snapshot) {
          String userName = snapshot.data?['name'] ?? "User";
          String imageUrl = snapshot.data?['image'] ?? "";
          return Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white24,
                backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : const AssetImage('images/person.png') as ImageProvider,
              ),
              const SizedBox(width: 12),
              Text('Hi, $userName', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                  child: const Icon(Icons.person_outline, color: Colors.white, size: 22),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sos() {
    return Center(
      child: SizedBox(
        height: 220, width: 220,
        child: AnimatedBuilder(
          animation: _waveController,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                _buildWave(0.0), _buildWave(0.33), _buildWave(0.66),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EmergencyScreen())),
                  child: Container(
                    height: 110, width: 110,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFD32F2F)),
                    child: const Center(child: Text('SOS', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold))),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildWave(double delay) {
    double progress = (_waveController.value + delay) % 1;
    double size = 110 + (progress * 120);
    double opacity = (1 - progress).clamp(0.0, 1.0);
    return Container(
      height: size, width: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFE53935).withOpacity(0.3 * opacity)),
    );
  }

  Widget _quickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _actionItem('call.png', 'Fake call', () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FakeCallScreen()))),
          _actionItem('location.png', 'Share location', () => Navigator.push(context, MaterialPageRoute(builder: (context) => const StartTripScreen()))),
          _actionItem('mic.png', 'Voice password', () => Navigator.push(context, MaterialPageRoute(builder: (context) => const VoicePasswordIntroScreen()))),
        ],
      ),
    );
  }

  Widget _actionItem(String imageName, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: CornerBorderPainter(),
        child: Container(
          height: 95, width: 95, alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('images/$imageName', width: 38, height: 38),
              const SizedBox(height: 8),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _safetyStatusCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity, padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Today's Safety Status", style: TextStyle(fontSize: 17)),
            const SizedBox(height: 12),
            Row(
              children: const [
                Icon(Icons.circle, color: Color(0xFF4CAF50), size: 12),
                SizedBox(width: 10),
                Text("You Are Safe", style: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _locationCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FullMapScreen())),
        child: Container(
          height: 200,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8))]),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: GoogleMap(initialCameraPosition: CameraPosition(target: _currentLatLng, zoom: 15), zoomControlsEnabled: false, myLocationButtonEnabled: false, onMapCreated: (c) => _googleMapController = c),
              ),
              Positioned(
                left: 14, right: 14, bottom: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined, color: Colors.blue, size: 22),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_locationText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomNav() {
    return Container(
      height: 70,
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _bottomItem(Icons.home_rounded, "Home", 0),
          _bottomItem(Icons.account_circle_outlined, "Contacts", 1),
          _bottomItem(Icons.file_copy_sharp, "Reports", 2),
          _bottomItem(Icons.settings_rounded, "Settings", 3),
        ],
      ),
    );
  }

  Widget _bottomItem(IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: isSelected ? const Color(0xFFCB30E0) : Colors.transparent, borderRadius: BorderRadius.circular(30)),
        child: Row(
          children: [
            Icon(icon, size: 22, color: isSelected ? Colors.white : Colors.grey.shade400),
            if (isSelected) ...[const SizedBox(width: 6), Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))],
          ],
        ),
      ),
    );
  }
}

class CornerBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFCB30E0).withOpacity(0.5)..strokeWidth = 2..style = PaintingStyle.stroke;
    double c = 12;
    canvas.drawPath(ui.Path()..moveTo(0, c)..lineTo(0, 0)..lineTo(c, 0), paint);
    canvas.drawPath(ui.Path()..moveTo(size.width - c, 0)..lineTo(size.width, 0)..lineTo(size.width, c), paint);
    canvas.drawPath(ui.Path()..moveTo(0, size.height - c)..lineTo(0, size.height)..lineTo(c, size.height), paint);
    canvas.drawPath(ui.Path()..moveTo(size.width - c, size.height)..lineTo(size.width, size.height)..lineTo(size.width, size.height - c), paint);
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}