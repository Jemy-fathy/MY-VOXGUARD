import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/colors.dart';
import '../emergency_screen.dart';
import 'live_location_screen.dart';

class AreYouOkayScreen extends StatefulWidget {
  final bool testMode;

  const AreYouOkayScreen({super.key, this.testMode = false});

  @override
  _AreYouOkayScreenState createState() => _AreYouOkayScreenState();
}

class _AreYouOkayScreenState extends State<AreYouOkayScreen> {
  static const int _initialTimerSeconds = 60; // 1 minute
  int _currentSeconds = _initialTimerSeconds;
  Timer? _timer;

  String _userName = '';
  String? _localProfileImagePath;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? firstName = prefs.getString('first_name');
    final String? lastName = prefs.getString('last_name');
    final String? localImg = prefs.getString('local_profile_image');

    if (mounted) {
      setState(() {
        _localProfileImagePath = localImg;

        final String fullName = [firstName, lastName]
            .where((n) => n != null && n.isNotEmpty)
            .join(' ');

        if (fullName.isNotEmpty) {
          _userName = context.locale.languageCode == 'ar'
              ? 'أهلاً $fullName'
              : 'Hi, $fullName';
        } else {
          _userName = context.locale.languageCode == 'ar' ? 'أهلاً' : 'Hi';
        }
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentSeconds > 0) {
        setState(() {
          _currentSeconds--;
        });
      } else {
        _timer?.cancel();
        _triggerSOS();
      }
    });
  }

  void _triggerSOS() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const EmergencyScreen(),
      ),
    );
  }

  void _snooze() {
    _timer?.cancel();
    // Go back to LiveLocationScreen, then after 5 minutes re-open AreYouOkayScreen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const LiveLocationScreen(),
      ),
    );
    Future.delayed(const Duration(minutes: 5), () {
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const AreYouOkayScreen(),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int minutes = _currentSeconds ~/ 60;
    final int seconds = _currentSeconds % 60;

    final String minutesStr = minutes.toString().padLeft(2, '0');
    final String secondsStr = seconds.toString().padLeft(2, '0');
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'images/Map.png',
            fit: BoxFit.cover,
          ),
          Container(
            color: Colors.white.withOpacity(0.3),
          ),
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 32.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── User avatar + name ──
                      if (_userName.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.grey.shade300,
                              backgroundImage: _localProfileImagePath != null &&
                                      _localProfileImagePath!.isNotEmpty
                                  ? FileImage(File(_localProfileImagePath!))
                                  : const AssetImage('images/person.png')
                                      as ImageProvider,
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                _userName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(height: 1, color: Color(0xFFEEEEEE)),
                        const SizedBox(height: 20),
                      ],
                      // ── Title ──
                      Text(
                        'are_you_okay'.tr(),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'are_you_okay_desc'.tr(),
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildTimeBlock(minutesStr, 'minutes'.tr()),
                          const SizedBox(width: 20),
                          _buildTimeBlock(secondsStr, 'seconds'.tr()),
                        ],
                      ),
                      const SizedBox(height: 40),
                       _ActionGradientButton(
                        text: 'im_safe'.tr(),
                        colors: [
                          const Color(0xFFCB30E0).withOpacity(0.8),
                          const Color(0xFFCB30E0).withOpacity(0.8),
                        ],
                        onPressed: () {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/home',
                            (route) => false,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _ActionGradientButton(
                        text: 'send_sos_now'.tr(),
                        onPressed: _triggerSOS,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _snooze,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE0E0E0),
                            foregroundColor: const Color(0xFF757575),
                            elevation: 5,
                            shadowColor: Colors.black.withOpacity(0.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: Text(
                            'snooze_5_min'.tr(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBlock(String timeValue, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 125,
          height: 85,
          decoration: BoxDecoration(
            color: const Color(0xFFF3E5F5),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            timeValue,
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}



class _ActionGradientButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final List<Color>? colors;

  const _ActionGradientButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: colors ??
              [
                const Color(0xFFE14DF2),
                const Color(0xFFD546F3),
              ],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onPressed,
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
