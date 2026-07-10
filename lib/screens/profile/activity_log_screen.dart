import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  String? _sosTime;
  String? _tripTime;
  String? _reportTime;
  String? _locationTime;
  String? _fakeCallTime;
  String? _wearableTime;

  @override
  void initState() {
    super.initState();
    _loadTimes();
  }

  Future<void> _loadTimes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _sosTime = prefs.getString('activity_log_sos_time');
        _tripTime = prefs.getString('activity_log_trip_time');
        _reportTime = prefs.getString('activity_log_report_time');
        _locationTime = prefs.getString('activity_log_location_time');
        _fakeCallTime = prefs.getString('activity_log_fake_call_time');
        _wearableTime = prefs.getString('activity_log_wearable_time');
      });
    } catch (e) {
      debugPrint("Error loading activity log times: $e");
    }
  }

  String _formatLogTime(String? timestampIso, String fallback) {
    if (timestampIso == null || timestampIso.isEmpty) {
      return fallback;
    }
    try {
      final dateTime = DateTime.parse(timestampIso).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final itemDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

      final String langCode = context.locale.languageCode;

      if (itemDate == today) {
        if (langCode == 'ar') {
          return "اليوم ، ${DateFormat('h:mm a', 'ar').format(dateTime)}";
        } else {
          return "Today , ${DateFormat('h:mm a', 'en').format(dateTime)}";
        }
      } else if (itemDate == yesterday) {
        if (langCode == 'ar') {
          return "أمس الساعة ${DateFormat('h:mm a', 'ar').format(dateTime)}";
        } else {
          return "Yesterday at ${DateFormat('h:mm a', 'en').format(dateTime)}";
        }
      } else {
        if (langCode == 'ar') {
          return "${DateFormat('d MMMM yyyy', 'ar').format(dateTime)} الساعة ${DateFormat('h:mm a', 'ar').format(dateTime)}";
        } else {
          return "${DateFormat('MMMM d, yyyy', 'en').format(dateTime)} at ${DateFormat('h:mm a', 'en').format(dateTime)}";
        }
      }
    } catch (e) {
      debugPrint("Error formatting date: $e");
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: 250,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFF8E9EFE), Color(0xFFD546F3)],
              ),
            ),
          ),
          Column(
            children: [
              Container(
                height: 140,
                padding: const EdgeInsets.only(top: 50, left: 10, right: 10),
                child: Row(
                  textDirection: context.locale.languageCode == 'ar' ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, 
                        size: 22
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'active_log'.tr(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold),
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
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, -2),
                      )
                    ],
                  ),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
                    children: [
                      _buildUnifiedCard(
                        imagePath: 'images/sos.png',
                        title: "sos_triggered".tr(),
                        time: _formatLogTime(_sosTime, "today_time".tr()),
                        description: "sos_description".tr(),
                        isSpecial: true,
                      ),
                      _buildUnifiedCard(
                        imagePath: 'images/Trip.png',
                        title: "trip_started".tr(),
                        time: _formatLogTime(_tripTime, "yesterday_time".tr()),
                        description: "trip_description".tr(),
                      ),
                      _buildUnifiedCard(
                        imagePath: 'images/Report copy.png',
                        title: "report_submitted".tr(),
                        time: _formatLogTime(_reportTime, "july_date".tr()),
                        description: "report_description".tr(),
                      ),
                      _buildUnifiedCard(
                        icon: Icons.location_on_outlined,
                        title: "location_shared_log".tr(),
                        time: _formatLogTime(_locationTime, "july_date".tr()),
                        description: "location_shared_description".tr(),
                      ),
                      _buildUnifiedCard(
                        imagePath: 'images/call.png',
                        title: "fake_call_log".tr(),
                        time: _formatLogTime(_fakeCallTime, "july_date".tr()),
                        description: "fake_call_description".tr(),
                      ),
                      _buildUnifiedCard(
                        icon: Icons.watch_outlined,
                        title: "wearable_trigger".tr(),
                        time: _formatLogTime(_wearableTime, "july_date".tr()),
                        description: "heart_rate_log".tr(),
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

  Widget _buildUnifiedCard({
    String? imagePath,
    IconData? icon,
    required String title,
    required String time,
    required String description,
    bool isSpecial = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isSpecial ? const Color(0xFFF9F2FF) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isSpecial ? 0.12 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 30,
                height: 30,
                child: imagePath != null
                    ? Image.asset(imagePath, fit: BoxFit.contain)
                    : Icon(icon, color: const Color(0xFFD546F3), size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      time,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14.5,
              color: Color(0xFF2E2E2E),
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],  
      ),
    );
  }
}