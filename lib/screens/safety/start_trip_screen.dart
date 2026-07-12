import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
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

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 - math.cos((lat2 - lat1) * p)/2 + 
          math.cos(lat1 * p) * math.cos(lat2 * p) * 
          (1 - math.cos((lon2 - lon1) * p))/2;
    return 12742 * math.asin(math.sqrt(a)); // 2 * R; R = 6371 km
  }

  int _calculateEstimatedTime(double startLat, double startLng, double endLat, double endLng) {
    double distanceInKm = _calculateDistance(startLat, startLng, endLat, endLng);
    
    double averageSpeedKmh = 50.0;
    if (distanceInKm > 50) {
      averageSpeedKmh = 80.0; // highway speed
    } else if (distanceInKm < 5) {
      averageSpeedKmh = 25.0; // local city traffic
    }
    
    double timeInHours = distanceInKm / averageSpeedKmh;
    int timeInMinutes = (timeInHours * 60).round();
    
    if (timeInMinutes < 10) timeInMinutes = 10;
    return timeInMinutes;
  }

  @override
  void initState() {
    super.initState();
    zones = _getMockZones();
    _loadLocalContacts();
    _fetchContacts();
    _fetchZones();
  }

  List<dynamic> _getMockZones() {
    return [
      {"name": "Mansoura", "latitude": 31.0409, "longitude": 31.3785},
      {"name": "El Mahalla El Kubra", "latitude": 30.9763, "longitude": 31.1691},
      {"name": "Tanta", "latitude": 30.7865, "longitude": 31.0004},
      {"name": "Cairo", "latitude": 30.0444, "longitude": 31.2357},
      {"name": "Alexandria", "latitude": 31.2001, "longitude": 29.9187},
      {"name": "Giza", "latitude": 30.0131, "longitude": 31.2089},
      {"name": "Port Said", "latitude": 31.2653, "longitude": 32.3019},
      {"name": "Suez", "latitude": 29.9668, "longitude": 32.5498},
      {"name": "Luxor", "latitude": 25.6872, "longitude": 32.6396},
      {"name": "Aswan", "latitude": 24.0889, "longitude": 32.8998},
      {"name": "Asyut", "latitude": 27.1783, "longitude": 31.1859},
      {"name": "Ismailia", "latitude": 30.6043, "longitude": 32.2723},
      {"name": "Fayoum", "latitude": 29.3084, "longitude": 30.8428},
      {"name": "Zagazig", "latitude": 30.5877, "longitude": 31.5015},
      {"name": "Damietta", "latitude": 31.4175, "longitude": 31.8144},
      {"name": "Damanhur", "latitude": 31.0414, "longitude": 30.4705},
      {"name": "Minya", "latitude": 28.0871, "longitude": 30.7503},
      {"name": "Beni Suef", "latitude": 29.0744, "longitude": 31.0978},
      {"name": "Qena", "latitude": 26.1551, "longitude": 32.7160},
      {"name": "Sohag", "latitude": 26.5570, "longitude": 31.6948},
      {"name": "Hurghada", "latitude": 27.2579, "longitude": 33.8116},
      {"name": "Shibin El Kom", "latitude": 30.5510, "longitude": 31.0116},
      {"name": "Banha", "latitude": 30.4591, "longitude": 31.1856},
      {"name": "Kafr El Sheikh", "latitude": 31.1107, "longitude": 30.9388},
      {"name": "Arish", "latitude": 31.1321, "longitude": 33.8033},
      {"name": "Mallawi", "latitude": 27.7314, "longitude": 30.8415},
      {"name": "10th of Ramadan", "latitude": 30.3013, "longitude": 31.7432},
      {"name": "Bilbeis", "latitude": 30.4181, "longitude": 31.5647},
      {"name": "Mersa Matruh", "latitude": 31.3525, "longitude": 27.2361},
      {"name": "Qalyub", "latitude": 30.1332, "longitude": 31.2504},
      {"name": "Rosetta", "latitude": 31.4044, "longitude": 30.4164},
      {"name": "Dahab", "latitude": 28.5010, "longitude": 34.5160},
      {"name": "Sharm El Sheikh", "latitude": 27.9158, "longitude": 34.3299},
      {"name": "Zamalek", "latitude": 30.0632, "longitude": 31.2201},
      {"name": "Maadi", "latitude": 29.9602, "longitude": 31.2569},
      {"name": "Dokki", "latitude": 30.0396, "longitude": 31.2131},
      {"name": "Mohandessin", "latitude": 30.0571, "longitude": 31.1994},
      {"name": "Heliopolis", "latitude": 30.0911, "longitude": 31.3228},
      {"name": "Nasr City", "latitude": 30.0566, "longitude": 31.3435},
      {"name": "Sheikh Zayed", "latitude": 30.0468, "longitude": 30.9839},
      {"name": "6th of October", "latitude": 29.9716, "longitude": 30.9425},
      {"name": "Rehab", "latitude": 30.0604, "longitude": 31.4883},
      {"name": "Madinaty", "latitude": 30.0903, "longitude": 31.6264},
      {"name": "Sheraton", "latitude": 30.0975, "longitude": 31.3812},
      {"name": "Tagamoa", "latitude": 30.0263, "longitude": 31.4913},
    ];
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
      final String? token = prefs.getString('token') ?? prefs.getString('auth_token');

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
        } else if (response.data is List) {
          zones = response.data;
        } else {
          zones = _getMockZones();
        }
        isLoadingZones = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (zones.isEmpty) {
          zones = _getMockZones();
        }
        isLoadingZones = false;
      });
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
      final String? token = prefs.getString('token') ?? prefs.getString('auth_token');

      double lat = selectedLatitude ?? 30.0444;
      double long = selectedLongitude ?? 31.2357;

      double currentLat = 31.0409; // Default starting location (Mansoura)
      double currentLong = 31.3785;
      
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        currentLat = position.latitude;
        currentLong = position.longitude;
      } catch (_) {
        // Fallback to defaults
      }

      if (selectedLatitude == null || selectedLongitude == null) {
        lat = currentLat;
        long = currentLong;
      }

      int estimatedTimeMinutes = 30; // Default fallback
      if (selectedLatitude != null && selectedLongitude != null) {
        estimatedTimeMinutes = _calculateEstimatedTime(currentLat, currentLong, lat, long);
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
          "estimated_time": estimatedTimeMinutes,
          "trusted_contact_id": selectedContactId,
          "safety_notes": null,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final tripData = response.data['data'];
        final int tripId = tripData['id'];
        final int serverEstimatedTime = int.tryParse(tripData['estimated_time']?.toString() ?? '') ?? estimatedTimeMinutes;

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
            builder: (context) => LiveLocationScreen(
              tripId: tripId,
              estimatedTimeMinutes: serverEstimatedTime,
            ),
          ),
        );
      } else {
        throw Exception('Server returned status: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      if (e is DioException &&
          (e.type == DioExceptionType.connectionTimeout ||
           e.type == DioExceptionType.sendTimeout ||
           e.type == DioExceptionType.receiveTimeout ||
           e.type == DioExceptionType.connectionError ||
           (e.message != null && e.message!.contains('SocketException')))) {
        
        // Show auto-discovery dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('جاري البحث التلقائي عن السيرفر في الشبكة...'),
                ],
              ),
            ),
          ),
        );
        
        String? foundIp = await ApiConfig.autoDiscoverServer();
        if (context.mounted) Navigator.pop(context);
        
        if (foundIp != null) {
          // Retry starting trip with the new IP
          await _startTrip();
          return;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start trip: $e'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'تحديث الـ IP',
            textColor: Colors.white,
            onPressed: () => _showChangeIpDialog(context),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => isStartingTrip = false);
    }
  }

  void _showChangeIpDialog(BuildContext context) {
    final TextEditingController ipController = TextEditingController(text: ApiConfig.serverIp);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تغيير عنوان السيرفر (Server IP)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('أدخل عنوان الـ IP الخاص بجهاز الـ Mac حالياً:'),
            const SizedBox(height: 12),
            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                hintText: 'مثال: 192.168.1.29',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              String newIp = ipController.text.trim();
              if (newIp.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('custom_server_ip', newIp);
                ApiConfig.setServerIp(newIp);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('تم تحديث الـ IP إلى: $newIp. يرجى المحاولة مجدداً.')),
                  );
                }
              }
            },
            child: const Text('حفظ وتحديث'),
          ),
        ],
      ),
    );
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
      'mansoura': 'المنصورة',
      'el mahalla el kubra': 'المحلة الكبرى',
      'mahalla': 'المحلة الكبرى',
      'tanta': 'طنطا',
      'cairo': 'القاهرة',
      'alexandria': 'الإسكندرية',
      'giza': 'الجيزة',
      'port said': 'بورسعيد',
      'suez': 'السويس',
      'luxor': 'الأقصر',
      'aswan': 'أسوان',
      'asyut': 'أسيوط',
      'ismailia': 'الإسماعيلية',
      'fayoum': 'الفيوم',
      'zagazig': 'الزقازيق',
      'damietta': 'دمياط',
      'damanhur': 'دمنهور',
      'minya': 'المنيا',
      'beni suef': 'بني سويف',
      'qena': 'قنا',
      'sohag': 'سوهاج',
      'hurghada': 'الغردقة',
      'shibin el kom': 'شبين الكوم',
      'banha': 'بنها',
      'kafr el sheikh': 'كفر الشيخ',
      'arish': 'العريش',
      'mallawi': 'ملوي',
      '10th of Ramadan': 'العاشر من رمضان',
      '10th of ramadan': 'العاشر من رمضان',
      'bilbeis': 'بلبيس',
      'mersa matruh': 'مرسى مطروح',
      'qalyub': 'قليوب',
      'rosetta': 'رشيد',
      'dahab': 'دهب',
      'sharm el sheikh': 'شرم الشيخ',
      'zamalek': 'الزمالك',
      'maadi': 'المعادي',
      'new cairo': 'القاهرة الجديدة',
      'helwan': 'حلوان',
      'helwan industrial': 'حلوان الصناعية',
      'nasr city': 'مدينة نصر',
      'heliopolis': 'مصر الجديدة',
      'dokki': 'الدقي',
      'mohandessin': 'المهندسين',
      '6th of october': '٦ أكتوبر',
      '6 October': '٦ أكتوبر',
      '6 october': '٦ أكتوبر',
      'sheikh zayed': 'الشيخ زايد',
      'shubra': 'شبرا',
      'abbaseya': 'العباسية',
      'rehab': 'الرحاب',
      'madinaty': 'مدينتي',
      'sheraton': 'شيراتون',
      'tagamoa': 'التجمع',
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
                  ? (contact['image'].toString().startsWith('http')
                      ? Image.network(
                          contact['image'].toString(),
                          width: 50,
                          height: 65,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(),
                        )
                      : Image.file(
                          File(contact['image'].toString()),
                          width: 50,
                          height: 65,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(),
                        ))
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
