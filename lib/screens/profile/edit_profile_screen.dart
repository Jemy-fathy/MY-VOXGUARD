import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../config/api_config.dart';
import '../../config/colors.dart';

class ArabicDigitsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    
    String newText = newValue.text;
    for (int i = 0; i < english.length; i++) {
      newText = newText.replaceAll(english[i], arabic[i]);
    }
    
    return newValue.copyWith(
      text: newText,
      selection: newValue.selection,
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _bloodTypeController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // Multi-select lists
  List<String> _selectedAllergies = [];
  List<String> _selectedMedicalConditions = [];

  final List<String> _allergyOptions = [
    'Peanuts', 'Tree Nuts', 'Milk', 'Eggs', 'Wheat', 'Soy',
    'Fish', 'Shellfish', 'Penicillin', 'Aspirin', 'Ibuprofen',
    'Latex', 'Bee Stings', 'Dust Mites', 'Pollen', 'Mold',
  ];

  final List<String> _medicalConditionOptions = [
    'Asthma', 'Diabetes', 'Hypertension', 'Heart Disease',
    'Epilepsy', 'Anemia', 'Arthritis', 'Cancer', 'Depression',
    'Anxiety', 'Kidney Disease', 'Liver Disease', 'Thyroid Disease',
    'Migraine', 'Obesity', 'Osteoporosis',
  ];

  bool _isLoading = false;

  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
      if (file != null) {
        setState(() {
          _profileImage = File(file.path);
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('local_profile_image', file.path);
      }
    } catch (e) {
      print("Error picking image: $e");
    }
  }

  String _englishDigits(String input) {
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    for (int i = 0; i < arabic.length; i++) {
      input = input.replaceAll(arabic[i], english[i]);
    }
    return input;
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final dio = Dio();
      
      final String phoneToSend = _phoneController.text.trim().isNotEmpty
          ? _englishDigits(_phoneController.text.trim())
          : _savedPhoneNumber;

      final Map<String, dynamic> dataMap = {
        'first_name': _firstNameController.text,
        'last_name': _lastNameController.text,
        'email': _emailController.text,
        'blood_type': _bloodTypeController.text,
        'allergies': _selectedAllergies.join(', '),
        'medical_conditions': _selectedMedicalConditions.join(', '),
        'phone_number': phoneToSend,
      };

      if (_profileImage != null) {
        String fileName = _profileImage!.path.split('/').last;
        if (!fileName.contains('.')) {
          fileName += '.jpg';
        }
        dataMap['profile_image'] = await MultipartFile.fromFile(
          _profileImage!.path,
          filename: fileName,
        );
      }

      final formData = FormData.fromMap(dataMap);

      final response = await dio.post(
        ApiConfig.updateProfile,
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('first_name', _firstNameController.text);
          await prefs.setString('last_name', _lastNameController.text);
          final String fullName = "${_firstNameController.text} ${_lastNameController.text}".trim();
          await prefs.setString('user_name', fullName);
          await prefs.setString('email', _emailController.text);
          await prefs.setString('phone_number', phoneToSend);
          if (_profileImage != null) {
            await prefs.setString('local_profile_image', _profileImage!.path);
            await prefs.setString('user_image', _profileImage!.path);
          } else {
            try {
              final data = response.data['user'] ?? response.data;
              String? img = data['image'] ?? data['profile_image'] ?? data['avatar'] ?? data['profile_picture'] ?? data['profile_photo_url'];
              if (img != null && img.isNotEmpty) {
                final fullImgUrl = img.startsWith('http')
                    ? img
                    : '${ApiConfig.baseUrl.replaceAll('/api', '')}/storage/${img.replaceAll('public/', '')}';
                await prefs.setString('user_image', fullImgUrl);
              }
            } catch (_) {}
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Profile Updated Successfully'.tr()),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception('Failed to update profile');
      }
    } catch (e) {
      String msg = 'Failed to update profile. Please try again.'.tr();
      if (e is DioException) {
        print("Update Profile Error Details: ${e.response?.data}");
        print("Status Code: ${e.response?.statusCode}");
        if (e.response?.data != null && e.response?.data is Map) {
          msg = e.response?.data['message'] ?? msg;
          if (e.response?.data['errors'] != null) {
            var errors = e.response?.data['errors'] as Map;
            msg = errors.values.first[0].toString();
          }
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  final FocusNode _fnFirst = FocusNode();
  final FocusNode _fnLast = FocusNode();
  final FocusNode _fnEmail = FocusNode();
  final FocusNode _fnBlood = FocusNode();
  final FocusNode _fnPhone = FocusNode();

  String selectedFlag = "🇪🇬";
  String selectedCode = "+20";
  String _savedPhoneNumber = "+201551471741";

  final Map<String, String> _arabicCountryNames = {
    "+20": "مصر",
    "+966": "السعودية",
    "+971": "الإمارات",
    "+965": "الكويت",
    "+974": "قطر",
    "+962": "الأردن",
    "+970": "فلسطين",
    "+212": "المغرب",
    "+213": "الجزائر",
    "+216": "تونس",
    "+961": "لبنان",
    "+964": "العراق",
    "+968": "عمان",
    "+973": "البحرين",
    "+218": "ليبيا",
    "+249": "السودان",
    "+1": "الولايات المتحدة",
    "+44": "المملكة المتحدة",
    "+90": "تركيا",
  };

  @override
  void initState() {
    super.initState();
    _fnFirst.addListener(() => setState(() {}));
    _fnLast.addListener(() => setState(() {}));
    _fnEmail.addListener(() => setState(() {}));
    _fnBlood.addListener(() => setState(() {}));
    _fnPhone.addListener(() => setState(() {}));
    
    // Fetch profile data when screen opens
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      final dio = Dio();
      final response = await dio.get(
        ApiConfig.getProfile,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );
      
      if (response.statusCode == 200) {
        final data = response.data['user'] ?? response.data;
        setState(() {
          _firstNameController.text = data['first_name'] ?? '';
          _lastNameController.text = data['last_name'] ?? '';
          _emailController.text = data['email'] ?? '';
          _bloodTypeController.text = data['blood_type'] ?? '';
          // Parse comma-separated allergies and medical conditions
          final String rawAllergies = data['allergies'] ?? '';
          final String rawMedical = data['medical_conditions'] ?? '';
          _selectedAllergies = rawAllergies.isNotEmpty
              ? rawAllergies.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
              : [];
          _selectedMedicalConditions = rawMedical.isNotEmpty
              ? rawMedical.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
              : [];
          final String rawPhone = data['phone_number'] ?? '';
          final String activePhone = rawPhone.isNotEmpty 
              ? rawPhone 
              : (prefs.getString('phone_number') ?? '+201551471741');
          
          _savedPhoneNumber = activePhone;
          _phoneController.text = ''; // Keep it empty so hint is visible
          
          // Match flag & code if activePhone has a prefix
          if (activePhone.startsWith('+20')) {
            selectedFlag = "🇪🇬";
            selectedCode = "+20";
          } else if (activePhone.startsWith('+966')) {
            selectedFlag = "🇸🇦";
            selectedCode = "+966";
          } else if (activePhone.startsWith('+971')) {
            selectedFlag = "🇦🇪";
            selectedCode = "+971";
          } else if (activePhone.startsWith('+965')) {
            selectedFlag = "🇰🇼";
            selectedCode = "+965";
          } else if (activePhone.startsWith('+974')) {
            selectedFlag = "🇶🇦";
            selectedCode = "+974";
          } else if (activePhone.startsWith('+962')) {
            selectedFlag = "🇯🇴";
            selectedCode = "+962";
          } else if (activePhone.startsWith('+970')) {
            selectedFlag = "🇵🇸";
            selectedCode = "+970";
          } else if (activePhone.startsWith('+212')) {
            selectedFlag = "🇲🇦";
            selectedCode = "+212";
          } else if (activePhone.startsWith('+213')) {
            selectedFlag = "🇩🇿";
            selectedCode = "+213";
          } else if (activePhone.startsWith('+216')) {
            selectedFlag = "🇹🇳";
            selectedCode = "+216";
          } else if (activePhone.startsWith('+961')) {
            selectedFlag = "🇱🇧";
            selectedCode = "+961";
          } else if (activePhone.startsWith('+964')) {
            selectedFlag = "🇮🇶";
            selectedCode = "+964";
          } else if (activePhone.startsWith('+968')) {
            selectedFlag = "🇴🇲";
            selectedCode = "+968";
          } else if (activePhone.startsWith('+973')) {
            selectedFlag = "🇧🇭";
            selectedCode = "+973";
          } else if (activePhone.startsWith('+218')) {
            selectedFlag = "🇱🇾";
            selectedCode = "+218";
          } else if (activePhone.startsWith('+249')) {
            selectedFlag = "🇸🇩";
            selectedCode = "+249";
          } else if (activePhone.startsWith('+1')) {
            selectedFlag = "🇺🇸";
            selectedCode = "+1";
          } else if (activePhone.startsWith('+44')) {
            selectedFlag = "🇬🇧";
            selectedCode = "+44";
          } else if (activePhone.startsWith('+90')) {
            selectedFlag = "🇹🇷";
            selectedCode = "+90";
          }
        });
      }
    } catch (e) {
      if (e is DioException) {
        print("Fetch Profile Error Details: ${e.response?.data}");
      }
      debugPrint("Error fetching profile: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _fnFirst.dispose();
    _fnLast.dispose();
    _fnEmail.dispose();
    _fnBlood.dispose();
    _fnPhone.dispose();
    super.dispose();
  }

  String _localizeDigits(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < english.length; i++) {
      input = input.replaceAll(english[i], arabic[i]);
    }
    return input;
  }

  void _showBloodTypeBottomSheet() {
    final bloodTypes = [
      'O positive', 'O negative', 'A positive', 'A negative',
      'B positive', 'B negative', 'AB positive', 'AB negative'
    ];
    String tempSelected = _bloodTypeController.text;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text('Select Blood Type'.tr(),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: bloodTypes.length,
                  itemBuilder: (_, index) {
                    final item = bloodTypes[index];
                    final isSelected = tempSelected == item;
                    return InkWell(
                      onTap: () {
                        setSheetState(() {
                          tempSelected = item;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFD546F3).withOpacity(0.08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFD546F3)
                                : Colors.grey.shade200,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.tr(),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? const Color(0xFFD546F3)
                                      : Colors.black87,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle,
                                  color: Color(0xFFD546F3), size: 22)
                            else
                              Icon(Icons.circle_outlined,
                                  color: Colors.grey.shade400, size: 22),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _bloodTypeController.text = tempSelected;
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD546F3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Confirm'.tr(),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMultiSelectBottomSheet({
    required String title,
    required List<String> options,
    required List<String> selected,
    required void Function(List<String>) onConfirm,
  }) {
    List<String> tempSelected = List.from(selected);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: options.length,
                  itemBuilder: (_, index) {
                    final item = options[index];
                    final isSelected = tempSelected.contains(item);
                    return InkWell(
                      onTap: () {
                        setSheetState(() {
                          if (isSelected) {
                            tempSelected.remove(item);
                          } else {
                            tempSelected.add(item);
                          }
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFD546F3).withOpacity(0.08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFD546F3)
                                : Colors.grey.shade200,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.tr(),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? const Color(0xFFD546F3)
                                      : Colors.black87,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle,
                                  color: Color(0xFFD546F3), size: 22)
                            else
                              Icon(Icons.circle_outlined,
                                  color: Colors.grey.shade400, size: 22),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    onConfirm(tempSelected);
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD546F3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Confirm'.tr(),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionField({
    required String label,
    required String value,
    required String hint,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              value.isEmpty ? hint : value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: value.isEmpty ? Colors.grey.withOpacity(0.5) : Colors.black,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    List<TextInputFormatter>? formatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: focusNode,
          inputFormatters: formatters,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD546F3))),
          ),
        ),
      ],
    );
  }

  PopupMenuItem<Map<String, String>> _buildCountryItem(
      String flag, String name, String code) {
    bool isArabic = context.locale.languageCode == 'ar';
    String displayName = (isArabic && _arabicCountryNames.containsKey(code)) 
        ? _arabicCountryNames[code]! 
        : name;
    return PopupMenuItem(
      value: {"flag": flag, "code": code},
      child: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(child: Text(displayName, style: const TextStyle(fontSize: 14))),
          Text(isArabic ? _localizeDigits(code) : code, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isArabic = context.locale.languageCode == 'ar';
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
             colors: [AppColors.bgBlueLight, AppColors.bgPurpleLight, Colors.white],
            stops:  [0.0, 0.3, 0.7],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Logo and Brand Text
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'images/logo.png',
                    height: 40,
                  ),
                  const SizedBox(width: 8),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        Color(0xFF4983F6),
                        Color(0xFFC175F5),
                        Color(0XFFFBACB7),
                      ],
                    ).createShader(bounds),
                    child: Text(
                      'voxguard'.tr(),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.black,
                            size: 24
                          ),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ),
                    Center(
                      child: ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Color(0xFF4983F6),
                            Color(0xFFC175F5),
                            Color(0XFFFBACB7),
                          ],
                        ).createShader(bounds),
                        child: Text(
                          'Edit Profile'.tr(),
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                            child: _buildTextField(
                                label: 'First Name'.tr(),
                                controller: _firstNameController,
                                focusNode: _fnFirst,
                                hint: 'First Name'.tr())),
                        const SizedBox(width: 16),
                        Expanded(
                            child: _buildTextField(
                                label: 'Last Name'.tr(),
                                controller: _lastNameController,
                                focusNode: _fnLast,
                                hint: 'Last Name'.tr())),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                        label: 'Email'.tr(),
                        controller: _emailController,
                        focusNode: _fnEmail,
                        hint: 'Enter your email'.tr()),
                    const SizedBox(height: 16),
                    _buildSelectionField(
                      label: 'Blood Type'.tr(),
                      value: _bloodTypeController.text.isNotEmpty
                          ? _bloodTypeController.text.tr()
                          : '',
                      hint: 'O positive'.tr(),
                      onTap: _showBloodTypeBottomSheet,
                    ),
                    const SizedBox(height: 16),
                    _buildSelectionField(
                      label: 'Allergies'.tr(),
                      value: _selectedAllergies.isEmpty
                          ? ''
                          : _selectedAllergies.map((e) => e.tr()).join(', '),
                      hint: 'Peanuts, Tree Nuts...'.tr(),
                      onTap: () => _showMultiSelectBottomSheet(
                        title: 'Select Allergies'.tr(),
                        options: _allergyOptions,
                        selected: _selectedAllergies,
                        onConfirm: (list) => setState(() => _selectedAllergies = list),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSelectionField(
                      label: 'Medical Conditions'.tr(),
                      value: _selectedMedicalConditions.isEmpty
                          ? ''
                          : _selectedMedicalConditions.map((e) => e.tr()).join(', '),
                      hint: 'Asthma, Diabetes...'.tr(),
                      onTap: () => _showMultiSelectBottomSheet(
                        title: 'Select Medical Conditions'.tr(),
                        options: _medicalConditionOptions,
                        selected: _selectedMedicalConditions,
                        onConfirm: (list) => setState(() => _selectedMedicalConditions = list),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Phone Number'.tr(),
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 14)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            PopupMenuButton<Map<String, String>>(
                              offset: const Offset(0, 55),
                              constraints: const BoxConstraints(maxHeight: 400),
                              onSelected: (Map<String, String> country) {
                                setState(() {
                                  selectedFlag = country['flag']!;
                                  selectedCode = country['code']!;
                                  _phoneController.text = isArabic ? _localizeDigits(selectedCode) : selectedCode;
                                  _phoneController.selection =
                                      TextSelection.fromPosition(
                                    TextPosition(
                                        offset: _phoneController.text.length),
                                  );
                                });
                              },
                              itemBuilder: (context) => [
                                _buildCountryItem("🇪🇬", "Egypt", "+20"),
                                _buildCountryItem("🇸🇦", "Saudi Arabia", "+966"),
                                _buildCountryItem("🇦🇪", "UAE", "+971"),
                                _buildCountryItem("🇰🇼", "Kuwait", "+965"),
                                _buildCountryItem("🇶🇦", "Qatar", "+974"),
                                _buildCountryItem("🇯🇴", "Jordan", "+962"),
                                _buildCountryItem("🇵🇸", "Palestine", "+970"),
                                _buildCountryItem("🇲🇦", "Morocco", "+212"),
                                _buildCountryItem("🇩🇿", "Algeria", "+213"),
                                _buildCountryItem("🇹🇳", "Tunisia", "+216"),
                                _buildCountryItem("🇱🇧", "Lebanon", "+961"),
                                _buildCountryItem("🇮🇶", "Iraq", "+964"),
                                _buildCountryItem("🇴🇲", "Oman", "+968"),
                                _buildCountryItem("🇧🇭", "Bahrain", "+973"),
                                _buildCountryItem("🇱🇾", "Libya", "+218"),
                                _buildCountryItem("🇸🇩", "Sudan", "+249"),
                                _buildCountryItem("🇺🇸", "USA", "+1"),
                                _buildCountryItem("🇬🇧", "UK", "+44"),
                                _buildCountryItem("🇹🇷", "Turkey", "+90"),
                              ],
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 15),
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade200),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Text(selectedFlag,
                                        style: const TextStyle(fontSize: 22)),
                                    const Icon(Icons.keyboard_arrow_down,
                                        color: Colors.grey, size: 18),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _phoneController,
                                focusNode: _fnPhone,
                                keyboardType: TextInputType.phone,
                                inputFormatters: isArabic ? [ArabicDigitsFormatter()] : [],
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  hintText: _savedPhoneNumber,
                                  hintStyle: TextStyle(
                                      color: Colors.grey.withOpacity(0.5)),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 16),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                          color: Colors.grey.shade200)),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                          color: Colors.grey.shade200)),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFD546F3))),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Container(
                      width: double.infinity,
                      height: 55,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE040FB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFF4A80F1), width: 2),
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _updateProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text('Confirm'.tr(),
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: OutlinedButton(
                        onPressed: _pickImage,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF4A80F1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _profileImage != null 
                            ? 'image_selected'.tr()
                            : 'change_profile_picture'.tr(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.normal,
                              color: Colors.black)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
