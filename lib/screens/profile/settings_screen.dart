import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../auth/password/update_password_screen.dart';
import '/screens/device/pair_device_screen.dart';
import '/screens/profile/language_screen.dart';
import '/screens/profile/delete_account_screen.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool fakeCallStatus = true;
  bool panicButtonStatus = true;
  bool notificationStatus = true;
  bool voicePasswordStatus = true;

  final Color brandColor = const Color(0xFFCB30E0);

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
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Settings',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
                // Content Sheet
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
                        _buildSectionTitle('Account'),
                        _buildSettingTile(
                          null,
                          'Profile',
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
                          'Voice Password',
                          imageAsset: 'images/voice copy.png',
                          hasSwitch: true,
                          currentValue: voicePasswordStatus,
                          onChanged: (v) {
                            setState(() => voicePasswordStatus = v);
                          },
                        ),
                        _buildSettingTile(
                          Icons.watch_outlined,
                          'Wearable Devices',
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
                          'Change Password',
                          imageAsset: 'images/change.png',
                          hasArrow: true,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const UpdatePasswordScreen(),
                            ),
                          ),
                        ),
                        _buildSettingTile(
                          null,
                          'Fake call',
                          imageAsset: 'images/fack.png',
                          hasSwitch: true,
                          currentValue: fakeCallStatus,
                          onChanged: (v) {
                            setState(() => fakeCallStatus = v);
                          },
                        ),
                        _buildSettingTile(
                          null,
                          'Panic button',
                          imageAsset: 'images/panic.png',
                          hasSwitch: true,
                          currentValue: panicButtonStatus,
                          onChanged: (v) =>
                              setState(() => panicButtonStatus = v),
                        ),
                        const Divider(
                          thickness: 1.5,
                          height: 40,
                          color: Color(0xFFF0F0F0),
                        ),
                        _buildSectionTitle('General'),
                        _buildSettingTile(
                          null,
                          'Notifications',
                          imageAsset: 'images/Notification.png',
                          hasSwitch: true,
                          currentValue: notificationStatus,
                          onChanged: (v) =>
                              setState(() => notificationStatus = v),
                        ),
                        _buildSettingTile(
                          null,
                          'Language',
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
                      activeColor: brandColor,
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
        onPressed: ()=> Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DeleteAccountScreen(),)),
        child: const Text(
          'Log out',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
