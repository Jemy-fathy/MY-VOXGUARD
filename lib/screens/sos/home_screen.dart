import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedIndex = 0;
  late AnimationController _waveController;

  // Location.
  LatLng _currentLatLng = const LatLng(30.0444, 31.2357);
  String _locationText = "Locating...";
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionSub;
  LatLng? _lastGeocoded;

  // User Data.
  String _userName = "Loading...";
  String _userImage = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _initLocation();
    _loadUserPreferences();
  }

  Future<void> _loadUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? "User";
      _userImage = prefs.getString('user_image') ?? "";
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSub?.cancel();
    _waveController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // SOS - Manual Trigger
  // ---------------------------------------------------------------------------
  Future<void> _openActiveAlert() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EmergencyScreen()),
    );
  }

  // ---------------------------------------------------------------------------
  // Location Logic
  // ---------------------------------------------------------------------------
  Future<void> _initLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    try {
      final Position position = await Geolocator.getCurrentPosition();
      _onPosition(position, animate: true, forceGeocode: true);
    } catch (_) {}

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      ),
    ).listen((pos) => _onPosition(pos));
  }

  void _onPosition(Position position,
      {bool animate = false, bool forceGeocode = false}) {
    final latLng = LatLng(position.latitude, position.longitude);
    if (mounted) setState(() => _currentLatLng = latLng);

    if (animate) {
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
    }

    final bool movedFar = _lastGeocoded == null ||
        Geolocator.distanceBetween(
              _lastGeocoded!.latitude,
              _lastGeocoded!.longitude,
              latLng.latitude,
              latLng.longitude,
            ) >
            150;
    if (forceGeocode || movedFar) {
      _lastGeocoded = latLng;
      _getAddressFromLatLng(latLng.latitude, latLng.longitude);
    }
  }

  Future<void> _getAddressFromLatLng(double lat, double lon) async {
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1');
    try {
      final response = await http.get(url,
          headers: {'User-Agent': 'voxGuard', 'Accept-Language': 'en'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String displayName = data['display_name'] ?? "Unknown Location";
        List<String> parts = displayName.split(',');
        if (mounted) {
          setState(() => _locationText =
              parts.length > 2 ? "${parts[0]}, ${parts[1]}" : displayName);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _locationText =
            "${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}");
      }
    }
  }

  // ---------------------------------------------------------------------------
  // UI - Core Components
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildHomeContent(),
      TrustedContactsScreen(
        onBackPressed: () {
          setState(() {
            _selectedIndex = 0;
          });
        },
      ),
      CreateReportScreen(
        onBackPressed: () {
          setState(() {
            _selectedIndex = 0;
          });
        },
      ),
      SettingsScreen(
        onBackPressed: () {
          setState(() {
            _selectedIndex = 0;
          });
        },
      ),
    ];
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFF8E9EFE), Color(0xFFD546F3)])),
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
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30), topRight: Radius.circular(30))),
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
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white24,
            backgroundImage: _userImage.isNotEmpty
                ? NetworkImage(_userImage)
                : const AssetImage('images/man.jpg') as ImageProvider,
          ),
          const SizedBox(width: 12),
          Text('hi'.tr(args: [_userName]),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          GestureDetector(
            onTap: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()));
              _loadUserPreferences();
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5)),
              child: const Icon(Icons.person_outline,
                  color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sos() {
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
                _buildWave(0.0),
                _buildWave(0.33),
                _buildWave(0.66),
                GestureDetector(
                  onTap: _openActiveAlert,
                  child: Container(
                    height: 110,
                    width: 110,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: Color(0xFFD32F2F)),
                    child: const Center(
                        child: Text('SOS',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold))),
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
      height: size,
      width: size,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFE53935).withOpacity(0.3 * opacity)),
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
              'fake_call'.tr(),
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const FakeCallScreen()))),
          _actionItem(
              'location.png',
              'start_trip'.tr(),
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const StartTripScreen()))),
          _actionItem(
              'mic.png',
              'voice_password'.tr(),
              () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const VoicePasswordIntroScreen()))),
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
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500)),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("safety_status".tr(),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.circle, color: Colors.green, size: 12),
                const SizedBox(width: 10),
                Text(
                  "you_are_safe".tr(),
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: Text(
                "systems_normal".tr(),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
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
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (context) => const FullMapScreen())),
        child: Container(
          height: 200,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8))
          ]),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: GoogleMap(
                    initialCameraPosition:
                        CameraPosition(target: _currentLatLng, zoom: 15),
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    onMapCreated: (c) => _mapController = c),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18)),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          color: Colors.blue, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_locationText,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis)),
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
      decoration: BoxDecoration(color: Colors.white, boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
      ]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _bottomItem(Icons.home_rounded, "home_label".tr(), 0),
          _bottomItem(Icons.account_circle_outlined, "contacts_label".tr(), 1),
          _bottomItem(Icons.file_copy_sharp, "reports_label".tr(), 2),
          _bottomItem(Icons.settings_rounded, "settings_label".tr(), 3),
        ],
      ),
    );
  }

  Widget _bottomItem(IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFCB30E0) : Colors.transparent,
            borderRadius: BorderRadius.circular(30)),
        child: Row(
          children: [
            Icon(icon,
                size: 22, color: isSelected ? Colors.white : Colors.grey.shade400),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12))
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
        paint);
    canvas.drawPath(
        ui.Path()
          ..moveTo(size.width - c, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width, c),
        paint);
    canvas.drawPath(
        ui.Path()
          ..moveTo(0, size.height - c)
          ..lineTo(0, size.height)
          ..lineTo(c, size.height),
        paint);
    canvas.drawPath(
        ui.Path()
          ..moveTo(size.width - c, size.height)
          ..lineTo(size.width, size.height)
          ..lineTo(size.width, size.height - c),
        paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}