import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../config/api_config.dart';
import 'confirm_tracking_screen.dart';

class LiveLocationScreen extends StatefulWidget {
  final int? tripId;
  const LiveLocationScreen({super.key, this.tripId});

  @override
  State<LiveLocationScreen> createState() => _LiveLocationScreenState();
}

class _LiveLocationScreenState extends State<LiveLocationScreen> {
  bool _isSharing = true;
  bool _isSavingNote = false;

  Timer? _timer;
  Timer? _locationTimer;
  int _secondsRemaining = 15 * 60; // 15 minutes countdown

  final TextEditingController _safetyNotesController = TextEditingController();

  LatLng _currentLatLng = const LatLng(37.42796133580664, -122.085749655962);
  GoogleMapController? _googleMapController;

  @override
  void initState() {
    super.initState();
    _saveLocationTime();
    _startTimer();
    _startLocationUpdates();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _currentLatLng = LatLng(position.latitude, position.longitude);
        });
        _googleMapController?.animateCamera(
          CameraUpdate.newLatLng(_currentLatLng),
        );
      }
    } catch (e) {
      debugPrint("Error getting current location: $e");
    }
  }

  Future<void> _saveLocationTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('activity_log_location_time', DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint("Error saving location time: $e");
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isSharing) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          } else {
            // Time's up - auto stop sharing
            _timer?.cancel();
            _stopSharingAndEndTrip();
          }
        });
      }
    });
  }

  void _startLocationUpdates() {
    if (widget.tripId == null) return;
    
    // Update immediately once, then periodically
    _updateLocationOnServer();
    
    _locationTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (_isSharing) {
        _updateLocationOnServer();
      }
    });
  }

  Future<void> _updateLocationOnServer() async {
    if (widget.tripId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token');

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _currentLatLng = LatLng(position.latitude, position.longitude);
        });
        _googleMapController?.animateCamera(
          CameraUpdate.newLatLng(_currentLatLng),
        );
      }

      final dio = Dio();
      await dio.post(
        "${ApiConfig.baseUrl}/trips/${widget.tripId}/update-location",
        options: Options(
          headers: {
            "Accept": "application/json",
            "Authorization": "Bearer $token",
          },
        ),
        data: {
          "latitude": position.latitude,
          "longitude": position.longitude,
        },
      );
      print("Location updated on server: ${position.latitude}, ${position.longitude}");
    } catch (e) {
      print("Failed to update location on server: $e");
    }
  }

  Future<void> _stopSharingAndEndTrip() async {
    if (widget.tripId != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final String? token = prefs.getString('token');

        // Get locally saved notes to include with end trip
        final savedNotes = prefs.getString('trip_${widget.tripId}_notes');

        final dio = Dio();
        await dio.post(
          "${ApiConfig.baseUrl}/trips/${widget.tripId}/end",
          options: Options(
            headers: {
              "Accept": "application/json",
              "Authorization": "Bearer $token",
            },
          ),
          data: {
            if (savedNotes != null && savedNotes.isNotEmpty)
              "safety_notes": savedNotes,
          },
        );
        print("Trip ended successfully on server.");

        // Clean up local notes after successful send
        await prefs.remove('trip_${widget.tripId}_notes');
      } catch (e) {
        print("Failed to end trip: $e");
      }
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ConfirmTrackingScreen(),
      ),
    );
  }

  Future<void> _saveSafetyNotes() async {
    final notes = _safetyNotesController.text.trim();
    if (notes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('safety_note_hint'.tr())),
      );
      return;
    }

    setState(() => _isSavingNote = true);

    // Always save locally first
    try {
      final prefs = await SharedPreferences.getInstance();
      if (widget.tripId != null) {
        await prefs.setString('trip_${widget.tripId}_notes', notes);
      }
    } catch (e) {
      print("Failed to save notes locally: $e");
    }

    // Then try to save on server
    if (widget.tripId != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final String? token = prefs.getString('token');

        final dio = Dio();
        await dio.post(
          "${ApiConfig.baseUrl}/trips/${widget.tripId}/update-notes",
          options: Options(
            headers: {
              "Accept": "application/json",
              "Authorization": "Bearer $token",
            },
          ),
          data: {
            "safety_notes": notes,
          },
        );

        print("Notes saved on server successfully");
      } catch (e) {
        // Server save failed, but we already saved locally
        print("Server save failed (saved locally): $e");
      }
    }

    if (!mounted) return;
    // Always show success since notes are saved locally
    // and will be sent with the end trip request
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('safety_note_saved'.tr()),
        backgroundColor: Colors.green,
      ),
    );

    if (mounted) setState(() => _isSavingNote = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _locationTimer?.cancel();
    _safetyNotesController.dispose();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _localizeDigits(String input) {
    if (context.locale.languageCode != 'ar') return input;
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < english.length; i++) {
      input = input.replaceAll(english[i], arabic[i]);
    }
    return input;
  }

  @override
  Widget build(BuildContext context) {
    String formattedTime = _formatTime(_secondsRemaining);
    List<String> timeParts = formattedTime.split(':');

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Container(
            height: 160,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFF8E9EFE), Color(0xFFE040FB)],
              ),
            ),
          ),
          Column(
            children: [
              // Header
              Container(
                height: 140,
                width: double.infinity,
                padding: const EdgeInsets.only(top: 60, left: 16, right: 16),
                child: Row(
                  textDirection: context.locale.languageCode == 'ar' ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'live_location_title'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

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
                  padding: const EdgeInsets.only(top: 30, left: 24, right: 24),
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7F7F7),
                                  borderRadius: BorderRadius.circular(40),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      color: Color(0xFFE040FB),
                                      size: 32,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'share_my_location'.tr(),
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w400,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    CupertinoSwitch(
                                      value: _isSharing,
                                      activeTrackColor: Colors.red,
                                      onChanged: (bool value) {
                                        setState(() {
                                          _isSharing = value;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'sharing_for'.tr(),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildTimerBox(_localizeDigits(timeParts[0]), 'hours'.tr()),
                                  const SizedBox(width: 16),
                                  _buildTimerBox(_localizeDigits(timeParts[1]), 'minutes'.tr()),
                                  const SizedBox(width: 16),
                                  _buildTimerBox(_localizeDigits(timeParts[2]), 'seconds'.tr()),
                                ],
                              ),
                              const SizedBox(height: 32),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: ShaderMask(
                                  shaderCallback: (bounds) =>
                                      const LinearGradient(
                                        colors: [
                                          Color(0xFF8E9EFE),
                                          Color(0xFFE040FB),
                                        ],
                                      ).createShader(bounds),
                                  child: Text(
                                    'safety_notes'.tr(),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 120,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF2F2F2),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                                child: TextField(
                                  controller: _safetyNotesController,
                                  maxLines: null,
                                  keyboardType: TextInputType.multiline,
                                  textAlign: TextAlign.start,
                                  decoration: InputDecoration(
                                    hintText: 'safety_note_hint'.tr(),
                                    hintStyle: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 16,
                                    ),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton.icon(
                                  onPressed: _isSavingNote ? null : _saveSafetyNotes,
                                  icon: _isSavingNote
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.save_alt_rounded, color: Colors.white, size: 20),
                                  label: Text(
                                    'save_note'.tr(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF8E9EFE),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Container(
                                height: 266,
                                width: 266,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.grey.shade300, width: 1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: GoogleMap(
                                    initialCameraPosition: CameraPosition(target: _currentLatLng, zoom: 15),
                                    zoomControlsEnabled: false,
                                    myLocationButtonEnabled: false,
                                    myLocationEnabled: true,
                                    onMapCreated: (controller) => _googleMapController = controller,
                                    markers: {
                                      Marker(
                                        markerId: const MarkerId("current_loc"),
                                        position: _currentLatLng,
                                        infoWindow: const InfoWindow(title: "My Live Location"),
                                      ),
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        height: 55,
                        margin: const EdgeInsets.only(bottom: 40),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFCB30E0), Color(0xFFB523D5)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.blue, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFCB30E0).withOpacity(0.3),
                              spreadRadius: 1,
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          onPressed: _stopSharingAndEndTrip,
                          child: Text(
                            'stop_sharing'.tr(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimerBox(String digit, String label) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFF9F9F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              digit,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w300,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}
