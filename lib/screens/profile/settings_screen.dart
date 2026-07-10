import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/password/update_password_screen.dart';
import '/screens/device/pair_device_screen.dart';
import '/screens/profile/language_screen.dart';
import '/screens/profile/delete_account_screen.dart';
import '/screens/sos/ai_monitor.dart' show kEmotionDetectionKey;
import 'profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onBackPressed;
  const SettingsScreen({super.key, this.onBackPressed});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool fakeCallStatus = true;
  bool panicButtonStatus = true;
  bool notificationStatus = true;
  bool voicePasswordStatus = true;
  bool emotionDetectionStatus = true;

  final Color brandColor = const Color(0xFFCB30E0);

  @override
  void initState() {
    super.initState();
    _loadEmotionDetection();
    _loadPanicButtonStatus();
  }

  Future<void> _loadPanicButtonStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool('panic_button_enabled') ?? true;
    if (mounted) {
      setState(() => panicButtonStatus = value);
    }
  }

  Future<void> _setPanicButtonStatus(bool value) async {
    setState(() => panicButtonStatus = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('panic_button_enabled', value);
  }

Future<void> _loadEmotionDetection() async {
  final prefs = await SharedPreferences.getInstance();
  final value = prefs.getBool(kEmotionDetectionKey) ?? true; 
  if (mounted) setState(() => emotionDetectionStatus = value);
}

Future<void> _setEmotionDetection(bool value) async {
  setState(() => emotionDetectionStatus = value);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(kEmotionDetectionKey, value); 
    FlutterBackgroundService().invoke('updateEmotionStatus', {'enabled': value});
  debugPrint("UI: Set $kEmotionDetectionKey to $value");
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Container(
            height: 200,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF8E9EFE), Color(0xFFE040FB)],
              ),
            ),
          ),
          SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  height: 140,
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 60, left: 16, right: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.chevron_left,
                          color: Colors.white,
                          size: 30,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          if (widget.onBackPressed != null) {
                            widget.onBackPressed!();
                          } else {
                            Navigator.pop(context);
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'settings'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 25,
                      vertical: 25,
                    ),
                    child: Column(
                      children: [
                        _buildSectionTitle('account'.tr()),
                        _buildSettingTile(
                          null,
                          'profile'.tr(),
                          imageAsset: 'images/profile.png',
                          hasArrow: true,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProfileScreen(),
                            ),
                          ),
                        ),
                        _buildSettingTile(
                          null,
                          'voice_password_toggle'.tr(),
                          imageAsset: 'images/voice copy.png',
                          hasSwitch: true,
                          currentValue: voicePasswordStatus,
                          onChanged: (v) {
                            setState(() => voicePasswordStatus = v);
                          },
                        ),
                        _buildSettingTile(
                          Icons.watch_outlined,
                          'wearable_devices'.tr(),
                          hasArrow: true,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PairDeviceScreen(),
                            ),
                          ),
                        ),
                        _buildSettingTile(
                          null,
                          'change_password'.tr(),
                          imageAsset: 'images/change.png',
                          hasArrow: true,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const UpdatePasswordScreen(),
                            ),
                          ),
                        ),
                        _buildSettingTile(
                          null,
                          'fake_call'.tr(),
                          imageAsset: 'images/fack.png',
                          hasSwitch: true,
                          currentValue: fakeCallStatus,
                          onChanged: (v) {
                            setState(() => fakeCallStatus = v);
                          },
                        ),
                        _buildSettingTile(
                          null,
                          'panic_button'.tr(),
                          imageAsset: 'images/panic.png',
                          hasSwitch: true,
                          currentValue: panicButtonStatus,
                          onChanged: _setPanicButtonStatus,
                        ),
                        _buildSettingTile(
                          Icons.emoji_emotions_outlined,
                          'emotion'.tr(),
                          hasSwitch: true,
                          currentValue: emotionDetectionStatus,
                          onChanged: _setEmotionDetection,
                        ),
                        const Divider(
                          thickness: 1.5,
                          height: 40,
                          color: Color(0xFFF0F0F0),
                        ),
                        _buildSectionTitle('general'.tr()),
                        _buildSettingTile(
                          null,
                          'notifications'.tr(),
                          imageAsset: 'images/Notification.png',
                          hasSwitch: true,
                          currentValue: notificationStatus,
                          onChanged: (v) => setState(() => notificationStatus = v),
                        ),
                        _buildSettingTile(
                          null,
                          'language'.tr(),
                          imageAsset: 'images/Language.png',
                          hasArrow: true,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LanguageScreen(),
                            ),
                          ),
                        ),
                     
                        const SizedBox(height: 30),
                        _buildLogoutButton(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 10),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: Colors.blue[900]?.withOpacity(0.8),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingTile(
    IconData? icon,
    String title, {
    bool hasArrow = false,
    bool hasSwitch = false,
    String? imageAsset,
    bool currentValue = false,
    ValueChanged<bool>? onChanged,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0XffF3F3F3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        leading: imageAsset != null
            ? Image.asset(imageAsset, width: 22, color: brandColor)
            : Icon(icon, color: brandColor, size: 22),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        trailing: hasArrow
            ? const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey)
            : (hasSwitch
                ? CupertinoSwitch(
                    activeTrackColor: brandColor,
                    value: currentValue,
                    onChanged: onChanged,
                  )
                : null),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        color: brandColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF4A80F1), width: 2),
      ),
      child: TextButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const DeleteAccountScreen(),
          ),
        ),
        child: Text(
          'logout'.tr(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}