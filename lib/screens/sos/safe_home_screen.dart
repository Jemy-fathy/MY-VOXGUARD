import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
// 🌟 استيراد مكتبة الخلفية لإدارتها من زر الأمان
import 'package:flutter_background_service/flutter_background_service.dart';
import 'dart:ui' as ui;
import 'home_screen.dart';
import '../map/map_screen.dart';
import '../profile/profile_screen.dart';
import '../profile/settings_screen.dart';
import '../reports/create_report_screen.dart';
import '../safety/start_trip_screen.dart' show StartTripScreen;
import '../safety/trusted_contacts_screen.dart';
import '../fake_call/fake_call_screen.dart';
import '../voice_password/voice_password_intro_screen.dart';

class SafeHomeScreen extends StatefulWidget {
  final int? sosId; 
  final String? token;
  final bool isLocationSharing;
  final bool isAudioRecording;

  const SafeHomeScreen({
    super.key, 
    this.sosId,
    this.token,
    this.isLocationSharing = true,
    this.isAudioRecording = true,
  });

  @override
  State<SafeHomeScreen> createState() => _SafeHomeScreenState();
}

class _SafeHomeScreenState extends State<SafeHomeScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _waveController;

  GoogleMapController? _googleMapController;
  LatLng _currentLatLng = const LatLng(30.0444, 31.2357);
  String _locationText = "Locating...";
  bool _isStopping = false;

  // 🌟 تايمر محلي خفيف لتحديث موقع الخريطة فقط أمام المستخدم بدون إرسال للسيرفر
  Timer? _uiLocationTimer;

  final String sosApiUrl = "http://192.168.1.191:8000/api/sos";

  final List<Widget> _pages = [
    const SizedBox.shrink(),
    const TrustedContactsScreen(),
    const CreateReportScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _determinePosition();

    // 🌟 تحديث دوري للخريطة المعروضة فقط لتلاحق المستخدم أثناء السير
    _uiLocationTimer = Timer.periodic(const Duration(seconds: 12), (timer) {
      _determinePosition();
    });
  }

  // --- ميثود إيقاف الاستغاثة وإرسال إشارة الأمان --- book---------- 
  Future<void> _stopSOS() async {
    final prefs = await SharedPreferences.getInstance();
    final int? currentSosId = widget.sosId ?? prefs.getInt('current_sos_id');
    final String? currentToken = widget.token ?? prefs.getString('token') ?? prefs.getString('auth_token');

    if (currentSosId == null) {
      _showSnackBar("Error: SOS ID not found.");
      return;
    }
    setState(() => _isStopping = true);
    final String fullUrl = "$sosApiUrl/$currentSosId/stop";
    try {
      final response = await http.post(
        Uri.parse(fullUrl),
        headers: {
          'Authorization': 'Bearer $currentToken',
          'Accept': 'application/json',
          'bypass-tunnel-reminder': 'true',
        },
      );

      if (response.statusCode == 200) {        
        final service = FlutterBackgroundService();
        var isRunning = await service.isRunning();
        if (isRunning) {
          service.invoke("stopService");
        }
        await Future.delayed(const Duration(seconds: 3));

        await prefs.remove('current_sos_id');
        
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      } else {
        _showSnackBar("Failed to stop SOS. Please try again.");
        if (mounted) setState(() => _isStopping = false);
      }
    } catch (e) {
      print("❌ Connection error: $e");
      _showSnackBar("Connection error.");
      if (mounted) setState(() => _isStopping = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<Map<String, String>> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString('user_name') ?? "User",
      'image': prefs.getString('user_image') ?? "",
    };
  }

  Future<void> _determinePosition() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _currentLatLng = LatLng(position.latitude, position.longitude);
        });
        _googleMapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_currentLatLng, 15),
        );
        _getAddressFromLatLng(position.latitude, position.longitude);
      }
    } catch (e) {
      debugPrint("Error fetching UI location: $e");
    }
  }

  Future<void> _getAddressFromLatLng(double lat, double lon) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1',
    );
    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'voxGuard', 'Accept-Language': 'en'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String displayName = data['display_name'] ?? "Unknown Location";
        List<String> parts = displayName.split(',');
        if (mounted) {
          setState(() {
            _locationText = parts.length > 2
                ? "${parts[0]}, ${parts[1]}"
                : displayName;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _locationText = "Location details unavailable");
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _uiLocationTimer?.cancel(); // 🌟 تنظيف التايمر المحلي لمنع أي Memory Leak
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFF8E9EFE), Color(0xFFD546F3)],
          ),
        ),
        child: _selectedIndex == 0
            ? _buildSafeMainContent()
            : _pages[_selectedIndex],
      ),
      bottomNavigationBar: _bottomNav(),
    );
  }

  Widget _buildSafeMainContent() {
    return Column(
      children: [
        const SizedBox(height: 40),
        _header(),
        const SizedBox(height: 30),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 25),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 5),
                _safeButton(),
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

  Widget _safeButton() {
    return Center(
      child: SizedBox(
        height: 220,
        width: 220,
        child: AnimatedBuilder(
          animation: _waveController,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                _buildSafeWave(0.0),
                _buildSafeWave(0.33),
                _buildSafeWave(0.66),
                GestureDetector(
                  onTap: _isStopping ? null : _stopSOS,
                  child: Container(
                    height: 110,
                    width: 110,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF4CAF50),
                    ),
                    child: Center(
                      child: _isStopping
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Safe',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSafeWave(double delay) {
    double progress = (_waveController.value + delay) % 1;
    double size = 110 + (progress * 120);
    double opacity = (1 - progress).clamp(0.0, 1.0);
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF4CAF50).withOpacity(0.3 * opacity),
      ),
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
                backgroundImage: imageUrl.isNotEmpty
                    ? NetworkImage(imageUrl)
                    : const AssetImage('images/person.png') as ImageProvider,
              ),
              const SizedBox(width: 12),
              Text(
                'Hi, $userName',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _quickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _actionItem(
            'call.png',
            'Fake call',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FakeCallScreen()),
            ),
          ),
          _actionItem(
            'location.png',
            'Share location',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StartTripScreen()),
            ),
          ),
          _actionItem(
            'mic.png',
            'Voice password',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const VoicePasswordIntroScreen(),
              ),
            ),
          ),
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
          height: 95,
          width: 95,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('images/$imageName', width: 38, height: 38),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
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
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Today's Safety Status", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.circle, color: Colors.red, size: 12),
                SizedBox(width: 10),
                Text(
                  "SOS Mode Active",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.only(left: 30),
              child: Text(
                "Contacts have been notified. Stay calm.",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
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
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const FullMapScreen()),
        ),
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentLatLng,
                    zoom: 15,
                  ),
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  onMapCreated: (controller) {
                    _googleMapController = controller;
                    _googleMapController?.animateCamera(
                      CameraUpdate.newLatLngZoom(_currentLatLng, 15),
                    );
                  },
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: Colors.blue,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _locationText,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Colors.grey,
                      ),
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
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
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
        duration: const Duration(milliseconds:0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFCB30E0) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? Colors.white : Colors.grey.shade400,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CornerBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCB30E0).withOpacity(0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    double c = 12;
    canvas.drawPath(
      ui.Path()
        ..moveTo(0, c)
        ..lineTo(0, 0)
        ..lineTo(c, 0),
      paint,
    );
    canvas.drawPath(
      ui.Path()
        ..moveTo(size.width - c, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, c),
      paint,
    );
    canvas.drawPath(
      ui.Path()
        ..moveTo(0, size.height - c)
        ..lineTo(0, size.height)
        ..lineTo(c, size.height),
      paint,
    );
    canvas.drawPath(
      ui.Path()
        ..moveTo(size.width - c, size.height)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width, size.height - c),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}