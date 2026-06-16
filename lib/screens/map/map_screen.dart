import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vox_guard/screens/map/manage_safety_places.dart';
import '../../config/colors.dart'; 
import '../sos/emergency_screen.dart';
import 'location_sheets.dart'; 
import '../../custom_widgets/custom_button.dart';

class FullMapScreen extends StatefulWidget {
  final bool startInPickingMode; 

  const FullMapScreen({super.key, this.startInPickingMode = false});

  @override
  State<FullMapScreen> createState() => _FullMapScreenState();
}

class _FullMapScreenState extends State<FullMapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final TextEditingController _searchController = TextEditingController();
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  LatLng? _currentPosition;
  double _currentBearing = 0.0; 
  Set<Marker> _markers = {};
  Set<Circle> _circles = {}; 
  
  Marker? _searchMarker; 
  
  Map<String, LatLng> _safePlaces = {};
  List<Map<String, dynamic>> _recentPlaces = [];
  final List<Map<String, dynamic>> _userCustomZones = [];

  bool _isPickingLocation = false;
  bool _isSelectingZoneLocation = false; 
  String? _pendingPlaceType;

  String _suggestedName = "Searching nearby...";
  String _suggestedDist = "";
  LatLng? _suggestedLocation;
  IconData _suggestionIcon = Icons.location_on;

  DateTime? _lastSosTime; 
  StreamSubscription<Position>? _positionStreamSubscription;

  final String _baseUrl = "http://192.168.1.191:8000/api";

  BitmapDescriptor? _homeIconCache;
  BitmapDescriptor? _workIconCache;
  BitmapDescriptor? _defaultSafeIconCache;

  @override
  void initState() {
    super.initState();
    _isSelectingZoneLocation = widget.startInPickingMode;
    _initializeData(); 
  }

  Future<void> _initializeData() async {
    await _preCacheMarkerIcons(); 
    await _loadDataFromLocal(); 
    await _fetchZonesFromServer(); 
    await _determinePosition();
    _startLiveTracking();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _searchController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _preCacheMarkerIcons() async {
    _homeIconCache = await _getBitmapFromIcon(Icons.home_rounded, Colors.blue);
    _workIconCache = await _getBitmapFromIcon(Icons.work_rounded, Colors.blue);
    _defaultSafeIconCache = await _getBitmapFromIcon(Icons.shield_rounded, Colors.blue);
  }

  void _startLiveTracking() {
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, 
      ),
    ).listen((Position position) {
      LatLng userPos = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          _currentPosition = userPos;
          _currentBearing = position.heading; 
        });
        
        _animateCameraToUser(userPos, position.heading);
        _checkGeofencing(userPos); 
        _getSmartSuggestion(position.latitude, position.longitude);
      }
    });
  }

  Future<void> _animateCameraToUser(LatLng pos, double bearing) async {
    try {
      final GoogleMapController c = await _controller.future;
      c.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: pos,
          zoom: 17.0,      
          bearing: bearing, 
          tilt: 30.0,      
        ),
      ));
    } catch (e) {
      debugPrint("Error moving camera: $e");
    }
  }

  void _checkGeofencing(LatLng userPos) async {
    if (_lastSosTime != null && 
        DateTime.now().difference(_lastSosTime!).inMinutes < 5) {
      return; 
    }

    try {
      for (var circle in _circles) {
        final String circleIdStr = circle.circleId.value.toLowerCase();
        
        // فحص ما إذا كانت المنطقة تابعة للنطاق الأحمر/الخطر
        if (circleIdStr.contains('danger') || 
            circleIdStr.contains('high_alert') || 
            circleIdStr.contains('red') ||
            circle.strokeColor == Colors.red) {
          
          double distance = Geolocator.distanceBetween(
            userPos.latitude, userPos.longitude,
            circle.center.latitude, circle.center.longitude
          );

          if (distance <= circle.radius) {
            // حل الثغرة الأساسية: فحص حالة الـ Switch الممررة داخل الـ ID
            bool shouldTriggerSos = circleIdStr.contains('triggersos_true');

            if (!shouldTriggerSos) {
              debugPrint("ℹ️ [UI Geofencing] Entered danger zone, but SOS trigger is turned OFF for this specific zone.");
              continue; // تخطي المنطقة وعدم تفعيل الطوارئ لالتزام برغبة المستخدم
            }

            _lastSosTime = DateTime.now(); 
            debugPrint("🚨 [UI Geofencing] Danger Zone & SOS Trigger Detected!");

            final bgService = FlutterBackgroundService();
            bool isRunning = await bgService.isRunning();
            
            if (!isRunning) {
              await bgService.startService();
            }

            if (mounted) {
              _navigateToEmergency();
            }
            break;
          }
        }
      }
    } catch (e) {
      debugPrint("❌ [UI Geofencing] Check failed: $e");
    }
  }

  void _navigateToEmergency() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EmergencyScreen()),
    );
  }

  Future<void> _shareLiveLocationSOS() async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('auth_token');

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      final response = await http.post(
        Uri.parse("$_baseUrl/sos/trigger"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "latitude": position.latitude,
          "longitude": position.longitude,
          "trigger_type": "manual"
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> resData = jsonDecode(response.body);
        int activeSosId = resData['data'] != null ? resData['data']['id'] : resData['id'];

        debugPrint("✅ Live Location SOS Started. ID: $activeSosId");
        await _launchSosGuard(sosId: activeSosId, token: token, isMock: false);
        return;
      }

      debugPrint("⚠️ Live Location SOS rejected (${response.statusCode}).");
    } catch (e) {
      debugPrint("❌ Error starting Live Location SOS: $e");
    }

    // Backend unreachable / rejected (e.g. local host down) → start a mock SOS so
    // live-location sharing still activates instead of silently doing nothing.
    final int mockId = -(DateTime.now().millisecondsSinceEpoch ~/ 1000);
    await prefs.setBool('sos_is_mock', true);
    debugPrint("🟡 Live Location SOS started in MOCK mode. ID: $mockId");
    await _launchSosGuard(sosId: mockId, token: token ?? 'mock-token', isMock: true);
  }

  /// Persists the active session, starts the background guard and opens the
  /// emergency screen. Shared by the real and mock live-location SOS paths.
  Future<void> _launchSosGuard({
    required int sosId,
    required String? token,
    required bool isMock,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('current_sos_id', sosId);
    await prefs.setBool('sos_is_mock', isMock);

    // Audio recording needs RECORD_AUDIO granted in the FOREGROUND: the
    // background isolate can't show a permission prompt, so if the mic isn't
    // already granted it silently skips recording. Resolve it here (where we
    // have a UI context) and only ask the guard to record when it's available.
    final bool canRecordAudio = await _ensureMicPermission();

    final bgService = FlutterBackgroundService();
    if (!await bgService.isRunning()) {
      await bgService.startService();
    }

    bgService.invoke('startSOS', {
      'sos_id': sosId,
      'token': token,
      'share_location': true,
      'record_audio': canRecordAudio,
    });

    if (mounted) {
      _navigateToEmergency();
    }
  }

  /// Ensures the microphone permission is granted before the SOS guard starts.
  /// Must run in the foreground — the background isolate can't prompt for it.
  /// Returns whether audio recording can proceed.
  Future<bool> _ensureMicPermission() async {
    var status = await Permission.microphone.status;
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Microphone is off. Enable it in Settings to record audio evidence.',
            ),
          ),
        );
      }
      return false;
    }

    status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> _fetchZonesFromServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('auth_token'); 

      final response = await http.get(
        Uri.parse("$_baseUrl/zones"),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      await _loadCustomZonesFromCache();

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> zonesData = responseData['data'] ?? [];
        
        await prefs.setString('cached_danger_zones', response.body);

        Set<Circle> combinedCircles = {};

        for (var z in zonesData) {
          double lat = double.parse((z['lat'] ?? z['latitude']).toString());
          double lng = double.parse((z['lng'] ?? z['longitude']).toString());
          double radius = double.parse(z['radius'].toString());
          String zoneId = z['id'].toString();
          String zoneName = z['name'] ?? "Custom User Zone";
          bool isAutomatic = z['is_automatic'] == true || z['is_automatic'] == 1;
          
          // قراءة حقل الـ Switch القادم من السيرفر وإرفاقه في الـ ID
          bool notifyAndTriggerSos = z['notify_contacts'] == true || z['notify_contacts'] == 1;
          
          String type = z['type'].toString().toLowerCase();
          Color zoneColor = (type == 'high_alert' || type == 'danger' || type == 'red') 
              ? Colors.red 
              : (type == 'safe' || type == 'blue') 
                  ? Colors.blue 
                  : Colors.orange;

          // تضمين حالة الـ trigger_sos بشكل صريح داخل حقل الـ circleId
          Circle circle = Circle(
            circleId: CircleId("server_${type}_${zoneId}_triggerSos_$notifyAndTriggerSos"),
            center: LatLng(lat, lng),
            radius: radius,
            fillColor: zoneColor.withOpacity(0.15),
            strokeColor: zoneColor,
            strokeWidth: 1,
          );

          combinedCircles.add(circle);

          if (!isAutomatic) {
            _userCustomZones.removeWhere((element) => element['name'] == zoneName);
            _userCustomZones.add({
              'id': circle.circleId.value, 
              'name': zoneName,
              'isZone': true,
              'isDanger': (type == 'high_alert' || type == 'danger' || type == 'red'),
              'lat': lat,
              'lng': lng,
              'radius': radius,
              'notify_contacts': notifyAndTriggerSos,
            });
          }
        }

        for (var localZone in _userCustomZones) {
          bool isDangerZone = localZone['isDanger'] == true;
          Color zoneColor = isDangerZone ? Colors.red : Colors.blue;
          combinedCircles.add(
            Circle(
              circleId: CircleId(localZone['id'].toString()),
              center: LatLng(localZone['lat'], localZone['lng']),
              radius: localZone['radius'],
              fillColor: zoneColor.withOpacity(0.15),
              strokeColor: zoneColor,
              strokeWidth: 1,
            ),
          );
        }

        setState(() {
          _circles = combinedCircles;
        });

        await _saveCustomZonesToCache(); 
      }
    } catch (e) {
      debugPrint("Error fetching zones: $e");
    }
  }

  Future<void> _saveZoneToServer(LatLng pos, double radius, String type, String name, bool notifyAndTriggerSos) async {
    String backendType;
    if (type.toLowerCase() == 'danger' || type.toLowerCase() == 'red' || type.toLowerCase() == 'high_alert') {
      backendType = 'high_alert';
    } else if (type.toLowerCase() == 'safe' || type.toLowerCase() == 'blue') {
      backendType = 'safe';
    } else {
      backendType = 'moderate';
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('auth_token');

      final response = await http.post(
        Uri.parse("$_baseUrl/zones"), 
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: json.encode({
          "name": name, 
          "latitude": pos.latitude,
          "longitude": pos.longitude,
          "radius": radius.toInt(),
          "type": backendType,
          "notify_family": true,
          "notify_contacts": notifyAndTriggerSos, 
        }),
      ).timeout(const Duration(seconds: 10)); 

      if (response.statusCode == 201 || response.statusCode == 200) {
        _fetchZonesFromServer(); 
      }
    } catch (e) {
      debugPrint("Caught Error saving zone: $e");
    }
  }

  Future<void> _loadDataFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    
    final placesJson = prefs.getString('safePlaces');
    if (placesJson != null) {
      final Map<String, dynamic> data = json.decode(placesJson);
      setState(() {
        _safePlaces = data.map((key, value) => MapEntry(key, LatLng(value['lat'], value['lng'])));
      });
    }

    final recentsJson = prefs.getString('recentPlaces');
    if (recentsJson != null) {
      setState(() => _recentPlaces = List<Map<String, dynamic>>.from(json.decode(recentsJson)));
    }
    await _loadCustomZonesFromCache();
    _refreshMarkers();
  }

  Future<void> _saveCustomZonesToCache() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> rawList = _userCustomZones.map((z) => json.encode({
      'id': z['id'].toString(),
      'name': z['name'],
      'isZone': true,
      'isDanger': z['isDanger'],
      'lat': z['lat'],
      'lng': z['lng'],
      'radius': z['radius'],
      'notify_contacts': z['notify_contacts'] ?? true,
    })).toList();
    await prefs.setStringList('user_custom_zones_local', rawList);
  }

  Future<void> _loadCustomZonesFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String>? rawList = prefs.getStringList('user_custom_zones_local');
      if (rawList != null) {
        _userCustomZones.clear(); 
        for (var item in rawList) {
          Map<String, dynamic> mapped = json.decode(item);
          _userCustomZones.add(mapped);
        }
      }
    } catch (e) {
      debugPrint("Error loading zones cache: $e");
    }
  }

  void _refreshMarkers() {
    Set<Marker> newMarkers = {};
    for (var entry in _safePlaces.entries) {
      BitmapDescriptor iconImage = _defaultSafeIconCache ?? BitmapDescriptor.defaultMarker;
      if (entry.key == "Home" && _homeIconCache != null) iconImage = _homeIconCache!;
      if (entry.key == "Work" && _workIconCache != null) iconImage = _workIconCache!;

      newMarkers.add(Marker(
        markerId: MarkerId(entry.key),
        position: entry.value,
        icon: iconImage,
      ));
    }
    if (_searchMarker != null) newMarkers.add(_searchMarker!);
    setState(() => _markers = newMarkers);
  }

  Future<BitmapDescriptor> _getBitmapFromIcon(IconData iconData, Color color) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);

    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(fontSize: 90.0, fontFamily: iconData.fontFamily, color: color),
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(0, 0));

    final ui.Image image = await pictureRecorder.endRecording().toImage(90, 90);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  Future<void> _determinePosition() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() => _currentPosition = LatLng(position.latitude, position.longitude));
      _getSmartSuggestion(position.latitude, position.longitude);
      
      if (widget.startInPickingMode) {
        _moveTo(LatLng(position.latitude, position.longitude));
        _animateSheet(0.15); 
      }
    } catch (e) {
      debugPrint("Error determining position: $e");
    }
  }

  void _onMapTap(LatLng position) async {
    if (_isSelectingZoneLocation) {
      setState(() => _isSelectingZoneLocation = false); 
      String placeName = await _getAddressFromLatLng(position); 

      if (!mounted) return;
      LocationSheets.showMarkLocationOptions(
        context, 
        position, 
        placeName, 
        (radius, type, notifyAndTriggerSos) {
          _saveZoneToServer(position, radius, type, placeName, notifyAndTriggerSos);
          _addNewCircleLocally(position, radius, type, placeName, notifyAndTriggerSos);
        }
      );
      _animateSheet(0.15);
    } 
    else if (_isPickingLocation) {
      if (_pendingPlaceType == "Home" || _pendingPlaceType == "Work") {
        _saveSafePlaceLocally(_pendingPlaceType!, position);
      } else {
        _showNameInputDialog(position);
      }
    }
  }

  void _addNewCircleLocally(LatLng pos, double radius, String type, String name, bool notifyAndTriggerSos) {
    // إرفاق حالة السويتش في معرف الدائرة المؤقتة أيضاً
    final CircleId tempId = CircleId("temp_${type}_${DateTime.now().millisecondsSinceEpoch}_triggerSos_$notifyAndTriggerSos");
    bool isDangerZone = (type == 'danger' || type == 'high_alert' || type == 'red');
    final Circle newCircle = Circle(
      circleId: tempId,
      center: pos,
      radius: radius,
      fillColor: isDangerZone ? Colors.red.withOpacity(0.15) : Colors.blue.withOpacity(0.15),
      strokeColor: isDangerZone ? Colors.red : Colors.blue,
      strokeWidth: 1,
    );

    setState(() {
      _circles.add(newCircle);
      _userCustomZones.add({
        'id': tempId.value,
        'name': name,
        'isZone': true,
        'isDanger': isDangerZone,
        'lat': pos.latitude,
        'lng': pos.longitude,
        'radius': radius,
        'notify_contacts': notifyAndTriggerSos,
      });
      _saveCustomZonesToCache(); 
    });
  }

  Future<void> _moveTo(LatLng pos) async {
    final c = await _controller.future;
    c.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: pos, zoom: 17)));       
  }

  void _animateSheet(double size) {
    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        size, 
        duration: const Duration(milliseconds: 300), 
        curve: Curves.easeInOut
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentPosition == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition!, 
              zoom: 15,
              bearing: _currentBearing, 
            ),
            myLocationEnabled: true,      
            myLocationButtonEnabled: true,
            markers: _markers,
            circles: _circles, 
            onMapCreated: (c) => _controller.complete(c),
            onTap: _onMapTap,
          ),
          
          if (_isSelectingZoneLocation || _isPickingLocation)
            Positioned(
              top: 100, left: 20, right: 20,
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: AppColors.primaryPurple, borderRadius: BorderRadius.circular(15)),
                child: Text(
                  "📍 Tap on map to set ${_isSelectingZoneLocation ? 'Zone' : (_pendingPlaceType ?? 'Place')}", 
                  textAlign: TextAlign.center, 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                ),
              ),
            ),

          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: widget.startInPickingMode ? 0.15 : 0.5,
            minChildSize: 0.15,
            maxChildSize: 0.75,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92), 
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildHandle(),
                    _buildSearchBar(),
                    const SizedBox(height: 20),
                    _buildSectionHeader("Safe Suggestions"),
                    _buildSuggestionCard(),
                    const SizedBox(height: 25),
                    _buildSectionHeader("Manage Places", showArrow: true, onTap: () => _navToManagePlaces()),
                    _buildSafePlacesRow(),
                    const SizedBox(height: 25),
                    _buildSectionHeader("Recent Searches"),
                    ..._recentPlaces.asMap().entries.map((entry) => _buildRecentTile(entry.key, entry.value)),
                    const SizedBox(height: 30),
                    CustomButton(
                      text: "Share Live Location", 
                      onPressed: _shareLiveLocationSOS,
                    ),
                    const SizedBox(height: 12),
                    CustomButton(
                      text: _isSelectingZoneLocation ? "Cancel Selection" : "Mark New Zone", 
                      onPressed: () {
                        setState(() {
                          _isSelectingZoneLocation = !_isSelectingZoneLocation;
                          if (_isSelectingZoneLocation) _isPickingLocation = false;
                        });
                        _animateSheet(_isSelectingZoneLocation ? 0.15 : 0.5);
                      }
                    ),
                    const SizedBox(height: 25),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        Expanded(child: TextField(
          controller: _searchController, 
          onSubmitted: (val) {
            _handleSearch(val);
            _animateSheet(0.15);
          }, 
          decoration: const InputDecoration(hintText: "Search for a location", border: InputBorder.none)
        )),
      ]),
    );
  }

  Widget _buildSafePlacesRow() {
    return Row(
      children: [
        _buildSafeCircle("Home", Icons.home_rounded, "Home"),
        const SizedBox(width: 20),
        _buildSafeCircle("Work", Icons.work_rounded, "Work"),
        const SizedBox(width: 20),
        _buildSafeCircle("Other", Icons.add, "Other"),
      ],
    );
  }

  Widget _buildSafeCircle(String label, IconData icon, String key) {
    bool exists = _safePlaces.containsKey(key);
    return GestureDetector(
      onTap: () async {
        if (exists) {
          await _moveTo(_safePlaces[key]!);
          _animateSheet(0.15);
        } else {
          setState(() {
            _isPickingLocation = true;
            _isSelectingZoneLocation = false; 
            _pendingPlaceType = key;
          });
          _animateSheet(0.15);
        }
      },
      child: Column(children: [
        Container(
          width: 65, height: 65,
          decoration: BoxDecoration(
            color: exists ? const Color(0xFFE1F0FF) : Colors.grey[100],
            shape: BoxShape.circle,
            border: exists ? Border.all(color: Colors.blue, width: 2) : null,
          ),
          child: Icon(icon, color: exists ? Colors.blue : Colors.grey, size: 30),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        Text(exists ? "Saved" : "Add", style: TextStyle(fontSize: 12, color: exists ? Colors.green : Colors.blue)),
      ]),
    );
  }

  Future<String> _getAddressFromLatLng(LatLng position) async {
    final url = "https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18";
    try {
      final response = await http.get(Uri.parse(url), headers: {'User-Agent': 'VoxGuard_App_v1'});
      final data = json.decode(response.body);
      return data['name'] ?? data['address']['road'] ?? "Point on Map";
    } catch (e) { return "Selected Location"; }
  }

  Future<void> _handleSearch(String input) async {
    if (input.isEmpty) return;
    final url = "https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(input)}&format=json&limit=1";
    try {
      final response = await http.get(Uri.parse(url), headers: {'User-Agent': 'VoxGuard_App_v1'});
      final data = json.decode(response.body);
      if (data.isNotEmpty) {
        final pos = LatLng(double.parse(data[0]['lat']), double.parse(data[0]['lon']));
        setState(() {
          _searchMarker = Marker(
            markerId: const MarkerId("search_result"),
            position: pos,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          );
        });
        _moveTo(pos); 
        _addToRecents(input, data[0]['display_name'], pos.latitude, pos.longitude);
        _refreshMarkers();
        _searchController.clear();
      }
    } catch (e) { debugPrint(e.toString()); }
  }

  void _addToRecents(String name, String addr, double lat, double lng) async {
    setState(() {
      _recentPlaces.removeWhere((item) => item['name'] == name);
      _recentPlaces.insert(0, {'name': name, 'address': addr, 'lat': lat, 'lng': lng});
    });
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('recentPlaces', json.encode(_recentPlaces));
  }

  void _saveSafePlaceLocally(String name, LatLng position) async {
    setState(() {
      _safePlaces[name] = position;
      _isPickingLocation = false; 
      _pendingPlaceType = null;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('safePlaces', json.encode(_safePlaces.map((k, v) => MapEntry(k, {'lat': v.latitude, 'lng': v.longitude}))));
    _refreshMarkers();
    _animateSheet(0.5); 
  }

  void _showNameInputDialog(LatLng position) {
    TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("New Safe Place"),
        content: TextField(controller: nameController, decoration: const InputDecoration(hintText: "Place name (e.g., Gym)")),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _isPickingLocation = false;
                _pendingPlaceType = null;
              });
              Navigator.pop(context);
              _animateSheet(0.5);
            }, 
            child: const Text("Cancel")
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                Navigator.pop(context);
                _saveSafePlaceLocally(nameController.text, position);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTile(int index, Map p) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: CircleAvatar(
        backgroundColor: Colors.orange.withOpacity(0.1),
        child: const Icon(Icons.history, color: Colors.orange, size: 20),
      ),
      title: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1),
      subtitle: Text(p['address'] ?? "", style: const TextStyle(fontSize: 12), maxLines: 1),
      trailing: IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () {
        setState(() => _recentPlaces.removeAt(index));
        SharedPreferences.getInstance().then((prefs) {
          prefs.setString('recentPlaces', json.encode(_recentPlaces));
        });
      }),
      onTap: () {
        _moveTo(LatLng(p['lat'], p['lng']));
        _animateSheet(0.15);
      },
    );
  }

  Widget _buildSectionHeader(String title, {bool showArrow = false, VoidCallback? onTap}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      if (showArrow) IconButton(icon: const Icon(Icons.arrow_forward_ios, size: 14), onPressed: onTap),
    ]);
  }

  Widget _buildHandle() => Center(child: Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))));

  Widget _buildSuggestionCard() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: Colors.blue, child: Icon(_suggestionIcon, color: Colors.white)),
        title: Text(_suggestedName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(_suggestedDist),
        onTap: () {
          if (_suggestedLocation != null) {
            _moveTo(_suggestedLocation!);
            _animateSheet(0.15);
          }
        },
      ),
    );
  }

  void _navToManagePlaces() async {
    final bool? shouldStartPicking = await Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => ManagePlacesScreen(
        places: _safePlaces,
        customZones: _userCustomZones, 
        onDelete: (key) { 
          setState(() => _safePlaces.remove(key)); 
          _refreshMarkers(); 
          SharedPreferences.getInstance().then((prefs) {
            prefs.setString('safePlaces', json.encode(_safePlaces.map((k, v) => MapEntry(k, {'lat': v.latitude, 'lng': v.longitude}))));
          });
        },
        onDeleteZone: (circleIdStr) { 
          setState(() {
            _circles.removeWhere((c) => c.circleId.value == circleIdStr);
            _userCustomZones.removeWhere((z) => z['id'] == circleIdStr);
          });
          _saveCustomZonesToCache(); 
        },
        onPlaceSelected: (LatLng position) {
          _moveTo(position);
          _animateSheet(0.15); 
        }, 
      ))
    );

    if (shouldStartPicking == true) {
      setState(() {
        _isSelectingZoneLocation = true;
        _isPickingLocation = false;
      });
      _animateSheet(0.15); 
    }
  }

  Future<void> _getSmartSuggestion(double lat, double lon) async {
    if (_safePlaces.isNotEmpty) {
      for (var entry in _safePlaces.entries) {
        double dist = Geolocator.distanceBetween(lat, lon, entry.value.latitude, entry.value.longitude);
        if (dist <= 300) { 
          setState(() {
            _suggestedName = "Your Saved ${entry.key}";
            _suggestedLocation = entry.value;
            _suggestedDist = "Located about ${dist.toInt()}m from you";
            _suggestionIcon = (entry.key == "Home") ? Icons.home_rounded : (entry.key == "Work" ? Icons.work_rounded : Icons.shield_rounded);
          });
          return; 
        }
      }
    }

    final url = "https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent('[out:json];(node["amenity"~"pharmacy|hospital|police|clinic"](around:500,$lat,$lon););out center;')}";
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
      final data = json.decode(response.body);
      if (data['elements'] != null && data['elements'].isNotEmpty) {
        var nearest = data['elements'][0];
        LatLng targetLoc = LatLng(nearest['lat'] ?? nearest['center']['lat'], nearest['lon'] ?? nearest['center']['lon']);
        double calculatedDist = Geolocator.distanceBetween(lat, lon, targetLoc.latitude, targetLoc.longitude);
        
        setState(() {
          _suggestedName = nearest['tags']['name'] ?? "Nearby Safe Point";
          _suggestedLocation = targetLoc;
          _suggestedDist = "Safe facility found around ${calculatedDist.toInt()}m";
          _suggestionIcon = Icons.health_and_safety;
        });
      } else {
        setState(() {
          _suggestedName = "Area Clear & Monitored";
          _suggestedLocation = LatLng(lat, lon);
          _suggestedDist = "No high alert entities detected within 500m";
          _suggestionIcon = Icons.gpp_good_rounded;
        });
      }
    } catch (e) { 
      debugPrint("Suggestion fallback: $e"); 
    }
  }
}