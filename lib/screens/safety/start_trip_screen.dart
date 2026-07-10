import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../../config/api_config.dart';
import 'live_location_screen.dart';

class StartTripScreen extends StatefulWidget {
  const StartTripScreen({super.key});

  @override
  State<StartTripScreen> createState() => _StartTripScreenState();
}

class _StartTripScreenState extends State<StartTripScreen> {
  final TextEditingController _destinationController = TextEditingController();
  
  List<dynamic> contacts = [];
  List<dynamic> zones = [];
  bool isLoading = true;
  bool isLoadingZones = true;
  int? selectedContactId;
  bool isStartingTrip = false;
  double? selectedLatitude;
  double? selectedLongitude;
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _loadLocalContacts();
    _fetchContacts();
    _fetchZones();
  }

  Future<void> _loadLocalContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? localData = prefs.getString('local_trusted_contacts');
    if (localData != null) {
      try {
        final List<dynamic> decoded = jsonDecode(localData);
        if (mounted) {
          setState(() {
            contacts = decoded;
            isLoading = false;
          });
        }
      } catch (e) {
        debugPrint("Error loading local contacts in StartTripScreen: $e");
      }
    }
  }

  Future<void> _fetchZones() async {
    if (!mounted) return;
    setState(() => isLoadingZones = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token');

      var response = await Dio().get(
        "${ApiConfig.baseUrl}/zones",
        options: Options(
          headers: {
            "Accept": "application/json",
            "Authorization": "Bearer $token",
          },
        ),
      );

      if (!mounted) return;
      setState(() {
        if (response.data is Map && response.data['data'] != null) {
          zones = response.data['data'];
        } else {
          zones = [];
        }
        isLoadingZones = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoadingZones = false);
    }
  }

  Future<void> _fetchContacts() async {
    if (!mounted) return;
    if (contacts.isEmpty) {
      setState(() => isLoading = true);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token') ?? prefs.getString('auth_token');

      var response = await Dio().get(
        "${ApiConfig.baseUrl}/trusted-contacts",
        options: Options(
          headers: {
            "Accept": "application/json",
            "Authorization": "Bearer $token",
          },
        ),
      );

      if (mounted) {
        setState(() {
          if (response.data is Map && response.data['contacts'] != null) {
            contacts = response.data['contacts'];
          } else {
            contacts = [];
          }
          isLoading = false;
        });
        await prefs.setString('local_trusted_contacts', jsonEncode(contacts));
      }
    } catch (e) {
      await _loadLocalContacts();
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _startTrip() async {
    final destination = _destinationController.text.trim();
    if (destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('enter_destination'.tr())),
      );
      return;
    }

    if (selectedContactId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('select_watcher_error'.tr())),
      );
      return;
    }

    setState(() => isStartingTrip = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token');

      double lat = selectedLatitude ?? 30.0444;
      double long = selectedLongitude ?? 31.2357;

      if (selectedLatitude == null || selectedLongitude == null) {
        try {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 5),
          );
          lat = position.latitude;
          long = position.longitude;
        } catch (_) {
          // Fallback to defaults
        }
      }

      final dio = Dio();
      final response = await dio.post(
        "${ApiConfig.baseUrl}/trips/start",
        options: Options(
          headers: {
            "Accept": "application/json",
            "Authorization": "Bearer $token",
          },
        ),
        data: {
          "destination_name": destination,
          "destination_lat": lat,
          "destination_long": long,
          "estimated_time": 30,
          "trusted_contact_id": selectedContactId,
          "safety_notes": null,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final tripData = response.data['data'];
        final int tripId = tripData['id'];

        // Save trip started and location shared timestamps
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('activity_log_trip_time', DateTime.now().toIso8601String());
          await prefs.setString('activity_log_location_time', DateTime.now().toIso8601String());
        } catch (e) {
          debugPrint("Error saving trip/location timestamps: $e");
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('trip_started_success'.tr()), backgroundColor: Colors.green),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LiveLocationScreen(tripId: tripId),
          ),
        );
      } else {
        throw Exception('Server returned status: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start trip: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => isStartingTrip = false);
    }
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

  String _getLocalizedZoneName(String englishName) {
    final Map<String, String> translations = {
      'zamalek': 'الزمالك',
      'maadi': 'المعادي',
      'new cairo': 'القاهرة الجديدة',
      'helwan': 'حلوان',
      'helwan industrial': 'حلوان الصناعية',
      'nasr city': 'مدينة نصر',
      'heliopolis': 'مصر الجديدة',
      'dokki': 'الدقي',
      'mohandessin': 'المهندسين',
      'giza': 'الجيزة',
      '6th of october': '٦ أكتوبر',
      '6 October': '٦ أكتوبر',
      '6 october': '٦ أكتوبر',
      'sheikh zayed': 'الشيخ زايد',
      'shubra': 'شبرا',
      'abbaseya': 'العباسية',
      'rehab': 'الرحاب',
      'madinaty': 'مدينتي',
      'sheraton': 'شيراتون',
    };
    
    final key = englishName.trim().toLowerCase();
    
    if (translations.containsKey(key)) {
      return translations[key]!;
    }
    
    // Fuzzy matching for similar names
    for (var entry in translations.entries) {
      if (key.contains(entry.key) || entry.key.contains(key)) {
        return entry.value;
      }
    }
    
    return englishName;
  }

  @override
  Widget build(BuildContext context) {
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
                      'start_trip_title'.tr(),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                  colors: [
                                    Color(0xFF8E9EFE),
                                    Color(0xFFE040FB)
                                  ],
                                ).createShader(bounds),
                                child: Text(
                                  'enter_destination'.tr(),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7F7F7),
                                  borderRadius: BorderRadius.circular(30),
                                  border:
                                      Border.all(color: Colors.grey.shade400),
                                ),
                                child: TextField(
                                  controller: _destinationController,
                                  textAlign: TextAlign.start,
                                  onChanged: (val) {
                                    setState(() {
                                      selectedLatitude = null;
                                      selectedLongitude = null;
                                      _showSuggestions = true;
                                    });
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'enter_destination'.tr(),
                                    hintStyle: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 18,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 16),
                                    suffixIcon: _destinationController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear, color: Colors.black54),
                                            onPressed: () {
                                              setState(() {
                                                _destinationController.clear();
                                                selectedLatitude = null;
                                                selectedLongitude = null;
                                                _showSuggestions = false;
                                              });
                                            },
                                          )
                                        : const Icon(Icons.search, color: Colors.black54),
                                  ),
                                ),
                              ),
                              // Autocomplete suggestions list
                              Builder(
                                builder: (context) {
                                  final query = _destinationController.text.trim().toLowerCase();
                                  if (!_showSuggestions || query.isEmpty) return const SizedBox.shrink();
                                  
                                  final filteredSuggestions = zones.where((zone) {
                                    final String englishName = (zone['name'] ?? '').toString();
                                    final String arabicName = _getLocalizedZoneName(englishName);
                                    
                                    final String englishLower = englishName.toLowerCase();
                                    final String arabicLower = arabicName.toLowerCase();
                                    
                                    return englishLower.contains(query) || arabicLower.contains(query);
                                  }).toList();
                                  
                                  if (filteredSuggestions.isEmpty) return const SizedBox.shrink();
                                  
                                  return Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.08),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      itemCount: filteredSuggestions.length,
                                      separatorBuilder: (context, index) => const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final zone = filteredSuggestions[index];
                                        final String englishName = zone['name'] ?? '';
                                        final String arabicName = _getLocalizedZoneName(englishName);
                                        
                                        final isArabic = context.locale.languageCode == 'ar';
                                        final String displayName = isArabic ? arabicName : englishName;
                                        
                                        return ListTile(
                                          leading: const Icon(Icons.location_on, color: Color(0xFFD546F3)),
                                          title: Text(
                                            displayName,
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87),
                                          ),
                                          onTap: () {
                                            setState(() {
                                              _destinationController.text = displayName;
                                              selectedLatitude = double.tryParse(zone['latitude'].toString());
                                              selectedLongitude = double.tryParse(zone['longitude'].toString());
                                              _showSuggestions = false;
                                            });
                                            FocusScope.of(context).unfocus();
                                          },
                                        );
                                      },
                                    ),
                                  );
                                }
                              ),
                              const SizedBox(height: 24),
                              ShaderMask(
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                  colors: [
                                    Color(0xFF8E9EFE),
                                    Color(0xFFE040FB)
                                  ],
                                ).createShader(bounds),
                                child: Text(
                                  'select_watcher'.tr(),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'watcher_notification_info'.tr(),
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade700,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 24),
                              isLoading
                                  ? const Center(child: CircularProgressIndicator())
                                  : contacts.isEmpty
                                      ? Center(child: Text("no_contacts".tr()))
                                      : Column(
                                          children: contacts.asMap().entries.map((entry) {
                                            int index = entry.key;
                                            dynamic contact = entry.value;
                                            return _buildWatcherCard(contact, index);
                                          }).toList(),
                                        ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      isStartingTrip
                          ? const CircularProgressIndicator()
                          : Container(
                              width: double.infinity,
                              height: 55,
                              margin: const EdgeInsets.only(bottom: 100),
                              decoration: BoxDecoration(
                                color: const Color(0xFFCB30E0),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: Colors.blue, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFCB30E0)
                                        .withOpacity(0.3),
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
                                onPressed: _startTrip,
                                child: Text(
                                  'start_trip'.tr(),
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

  Widget _buildWatcherCard(dynamic contact, int index) {
    int contactId = contact['id'] ?? 0;
    bool isSelected = selectedContactId == contactId;
    String name = contact['name'] ?? "${contact['first_name'] ?? ''} ${contact['last_name'] ?? ''}".trim();
    if (name.isEmpty) name = "no_name".tr();

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedContactId = isSelected ? null : contactId;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: contact['image'] != null && contact['image'].toString().isNotEmpty
                  ? Image.network(
                      contact['image'],
                      width: 50,
                      height: 65,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholder(),
                    )
                  : _buildPlaceholder(),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _localizeDigits(contact['phone'] ?? ''),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFD546F3),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      color: Color(0xFFD546F3),
                      size: 24,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 50,
      height: 65,
      color: Colors.grey[200],
      child: const Icon(Icons.person, color: Colors.grey),
    );
  }
}
