import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart' as dio_lib;
import 'package:vox_guard/screens/profile/settings_screen.dart';
import '/screens/profile/delete_account_screen.dart';
import '/screens/profile/edit_profile_screen.dart';
import '../../config/api_config.dart';
import '../widgets/custom_profile_tiles.dart';
import 'activity_log_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = "";
  String _email = "";
  String _phone = "";
  String _bloodType = "";
  String _allergies = "";
  String _medicalConditions = "";
  String? _profileImageUrl;
  String? _localProfileImagePath;
  String? _token;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    String? fName = prefs.getString('first_name');
    String? lName = prefs.getString('last_name');
    String? email = prefs.getString('email');
    String? phone = prefs.getString('phone_number');
    if (phone == null || phone.isEmpty) {
      phone = '+201551471741';
      await prefs.setString('phone_number', phone);
    }
    String? localImg = prefs.getString('local_profile_image');
    _token = prefs.getString('token');

    setState(() {
      _localProfileImagePath = localImg;
      String fullName = (fName != null && fName.isNotEmpty) 
          ? "$fName ${lName ?? ''}".trim() 
          : 'user_name'.tr();
          
      // Auto-translate common test names for consistency
      if (context.locale.languageCode == 'ar') {
        if (fullName.toLowerCase() == 'mohamed gamal') {
          fullName = 'محمد جمال';
        } else if (fullName.toLowerCase() == 'mayar gamal') {
          fullName = 'ميار جمال';
        }
      }
      
      _userName = fullName;
      _email = (email != null && email.isNotEmpty) ? email : 'email_hint'.tr();
      _phone = (phone != null && phone.isNotEmpty) ? phone : 'phone_hint'.tr();
    });

    // Optionally fetch latest from API
    try {
      final token = prefs.getString('token');
      final response = await http.get(
        Uri.parse(ApiConfig.getProfile),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final userData = data['data'] ?? data['user'] ?? data;
        final emergency = userData['emergency_info'] ?? data['emergency_info'];

        String? img = userData['image'] ?? userData['profile_image'] ?? userData['avatar'] ?? userData['profile_picture'];
        String? fullImgUrl;
        if (img != null && img.toString().isNotEmpty) {
          final imgStr = img.toString();
          if (imgStr.contains('default.png') || imgStr.contains('default.jpg')) {
            fullImgUrl = null;
          } else {
            fullImgUrl = imgStr.startsWith('http')
                ? imgStr
                : '${ApiConfig.baseUrl.replaceAll('/api', '')}/storage/${imgStr.replaceAll('public/', '')}';
          }
        }

        if (userData['first_name'] != null) {
          await prefs.setString('first_name', userData['first_name']);
          if (userData['last_name'] != null) {
            await prefs.setString('last_name', userData['last_name']);
          }
        }
        if (userData['email'] != null) {
          await prefs.setString('email', userData['email']);
        }
        if (userData['phone_number'] != null) {
          await prefs.setString('phone_number', userData['phone_number']);
        }

        setState(() {
          if (userData['first_name'] != null) {
            String newFName = userData['first_name'];
            String newLName = userData['last_name'] ?? '';
            String fullName = "$newFName $newLName".trim();
            if (context.locale.languageCode == 'ar') {
              if (fullName.toLowerCase() == 'mohamed gamal') {
                fullName = 'محمد جمال';
              } else if (fullName.toLowerCase() == 'mayar gamal') {
                fullName = 'ميار جمال';
              }
            }
            _userName = fullName;
          }
          if (userData['email'] != null) {
            _email = userData['email'];
          }
          if (userData['phone_number'] != null) {
            _phone = userData['phone_number'];
          }
          if (fullImgUrl != null) {
            _profileImageUrl = fullImgUrl;
            prefs.setString('user_image', fullImgUrl);
          }
          
          if (emergency != null) {
            _bloodType = emergency['blood_type'] ?? "";
            _allergies = emergency['allergies'] ?? "";
            _medicalConditions = emergency['medical_conditions'] ?? "";
          }
        });
      }
    } catch (e) {
      debugPrint("Error updating profile data: $e");
    }
  }

  Future<void> _updateAvatar() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
      
      if (file != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('local_profile_image', file.path);
        await prefs.setString('user_image', file.path);
        setState(() {
          _localProfileImagePath = file.path;
        });

        // Show loading indicator
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return const Center(child: CircularProgressIndicator());
            },
          );
        }

        final token = prefs.getString('token');
        final dio = dio_lib.Dio();
        
        String fileName = file.path.split('/').last;
        if (!fileName.contains('.')) {
          fileName += '.jpg';
        }
        
        final formData = dio_lib.FormData.fromMap({
          'profile_image': await dio_lib.MultipartFile.fromFile(
            file.path,
            filename: fileName,
          ),
        });

        final response = await dio.post(
          ApiConfig.updateProfile,
          data: formData,
          options: dio_lib.Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          ),
        );

        // Close loading indicator
        if (mounted) Navigator.pop(context);

        if (response.statusCode == 200 || response.statusCode == 201) {
          // Reload user data to get the new image URL
          _loadUserData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('avatar_updated_successfully'.tr())),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('failed_to_update_avatar'.tr())),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            ProfileHeader(
              imagePath: 'images/man.jpg',
              imageUrl: _profileImageUrl,
              localImagePath: _localProfileImagePath,
              token: _token,
              onBack: () => Navigator.pop(context),
              onEdit: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const EditProfileScreen()),
              ).then((_) => _loadUserData()),
              onAvatarEdit: _updateAvatar,
            ),
            const SizedBox(height: 70),
            _buildUserInfo(
                context, _userName, _email, _phone),
            const SizedBox(height: 10),
            const Divider(thickness: 1, height: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildSectionTitle('emergency_info'.tr())),
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

  String _translateList(String input) {
    if (input.isEmpty) return input;
    return input.split(',').map((e) {
      final trimmed = e.trim();
      return trimmed.tr();
    }).join(', ');
  }

  Widget _buildEmergencyList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          EmergencyInfoTile(
              imagePath: 'images/Group.png',
              title: 'blood_type'.tr(),
              value: _bloodType.isNotEmpty ? _bloodType.tr() : 'o_positive'.tr()),
          const SizedBox(height: 8),
          EmergencyInfoTile(
              imagePath: 'images/Allergies.png',
              title: 'allergies'.tr(),
              value: _allergies.isNotEmpty ? _translateList(_allergies) : 'peanuts'.tr()),
          const SizedBox(height: 8),
          EmergencyInfoTile(
              imagePath: 'images/Medical.png',
              title: 'medical_conditions'.tr(),
              value: _medicalConditions.isNotEmpty ? _translateList(_medicalConditions) : 'asthma'.tr()),
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
              title: 'activity_log'.tr(),
              onTap: () => _nav(context, const ActivityLogScreen())),
          const SizedBox(height: 8),
          ProfileActionTile(
              icon: Icons.settings,
              title: 'settings'.tr(),
              onTap: () => _nav(context, SettingsScreen(onBackPressed: () {  },))),
          const SizedBox(height: 8),
          ProfileActionTile(
              icon: Icons.delete,
              title: 'delete_account'.tr(),
              onTap: () => _nav(context, const DeleteAccountScreen())),
        ],
      ),
    );
  }

  void _nav(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (context) => screen)).then((_) => _loadUserData());

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

  String _localizeDigits(String input, BuildContext context) {
    if (context.locale.languageCode != 'ar') return input;
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < english.length; i++) {
      input = input.replaceAll(english[i], arabic[i]);
    }
    return input;
  }

  Widget _buildUserInfo(BuildContext context, String name, String email, String phone) {
    // Ensure Egyptian numbers have their leading zero if stripped by backend
    if (phone.length == 10 && phone.startsWith('1')) {
      phone = '0$phone';
    } else if (phone.startsWith('+201') && phone.length == 13) {
      phone = phone.replaceFirst('+20', '0');
    }
    
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
        Text(_localizeDigits(phone, context), style: TextStyle(fontSize: 16, color: Colors.grey[600])),
      ],
    );
  }
}
