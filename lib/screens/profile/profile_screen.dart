import 'package:flutter/material.dart';
import 'package:vox_guard/screens/profile/settings_screen.dart';
import '/screens/profile/delete_account_screen.dart';
import '/screens/profile/edit_profile_screen.dart';
import '../widgets/custom_profile_tiles.dart';
import 'activity_log_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            ProfileHeader(
              imagePath: 'images/man.jpg',
              onBack: () => Navigator.pop(context),
              onEdit: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const EditProfileScreen()),
              ),
            ),
            const SizedBox(height: 70),
            _buildUserInfo(
                'Mohamed Adel', 'moaboasy@gmail.com', '+201551471741'),
            const SizedBox(height: 10),
            const Divider(thickness: 1, height: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildSectionTitle('Emergency information')),
            ),
            _buildEmergencyList(),
            const SizedBox(height: 10),
            const Divider(thickness: 1, height: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 20),
            _buildActionList(context),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: const [
          EmergencyInfoTile(
              imagePath: 'images/Group.png',
              title: 'Blood Type',
              value: 'O Positive'),
          SizedBox(height: 8),
          EmergencyInfoTile(
              imagePath: 'images/Allergies.png',
              title: 'Allergies',
              value: 'Peanuts'),
          SizedBox(height: 8),
          EmergencyInfoTile(
              imagePath: 'images/Medical.png',
              title: 'Medical Conditions',
              value: 'Asthma'),
        ],
      ),
    );
  }

  Widget _buildActionList(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          ProfileActionTile(
              icon: Icons.local_activity,
              title: 'Activity log',
              onTap: () => _nav(context, const ActivityLogScreen())),
          const SizedBox(height: 8),
          ProfileActionTile(
              icon: Icons.settings,
              title: 'Settings',
              onTap: () => _nav(context, const SettingsScreen())),
          const SizedBox(height: 8),
          ProfileActionTile(
              icon: Icons.delete,
              title: 'Delete Account',
              onTap: () => _nav(context, const DeleteAccountScreen())),
        ],
      ),
    );
  }

  void _nav(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (context) => screen));

  Widget _buildSectionTitle(String title) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0XFF4983F6), Color(0xFFC175F5), Color(0XFFFBACB7)])
          .createShader(bounds),
      child: Text(title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildUserInfo(String name, String email, String phone) {
    return Column(
      children: [
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(colors: [
            Color(0XFF4983F6),
            Color(0xFFC175F5),
            Color(0XFFFBACB7)
          ]).createShader(bounds),
          child: Text(name,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        ),
        Text(email,
            style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                decoration: TextDecoration.underline)),
        Text(phone, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
      ],
    );
  }
}
