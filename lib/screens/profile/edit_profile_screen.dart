import 'package:flutter/material.dart';

import '../../config/colors.dart';

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
  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _medicalConditionsController =
      TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  final FocusNode _fnFirst = FocusNode();
  final FocusNode _fnLast = FocusNode();
  final FocusNode _fnEmail = FocusNode();
  final FocusNode _fnBlood = FocusNode();
  final FocusNode _fnAllergy = FocusNode();
  final FocusNode _fnMedical = FocusNode();
  final FocusNode _fnPhone = FocusNode();

  String selectedFlag = "🇪🇬";
  String selectedCode = "+20";

  @override
  void initState() {
    super.initState();

    _fnFirst.addListener(() => setState(() {}));
    _fnLast.addListener(() => setState(() {}));
    _fnEmail.addListener(() => setState(() {}));
    _fnBlood.addListener(() => setState(() {}));
    _fnAllergy.addListener(() => setState(() {}));
    _fnMedical.addListener(() => setState(() {}));
    _fnPhone.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _fnFirst.dispose();
    _fnLast.dispose();
    _fnEmail.dispose();
    _fnBlood.dispose();
    _fnAllergy.dispose();
    _fnMedical.dispose();
    _fnPhone.dispose();
    super.dispose();
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: focusNode,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
          decoration: InputDecoration(
            hintText: focusNode.hasFocus ? "" : hint,
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
    return PopupMenuItem(
      value: {"flag": flag, "code": code},
      child: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 14))),
          Text(code, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    child: const Text(
                      'voxguard',
                      style: TextStyle(
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
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
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
                        child: const Text(
                          'Edit profile',
                          style: TextStyle(
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
                                label: 'First Name',
                                controller: _firstNameController,
                                focusNode: _fnFirst,
                                hint: 'Mohamed')),
                        const SizedBox(width: 16),
                        Expanded(
                            child: _buildTextField(
                                label: 'Last Name',
                                controller: _lastNameController,
                                focusNode: _fnLast,
                                hint: 'Aboasy')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                        label: 'Email',
                        controller: _emailController,
                        focusNode: _fnEmail,
                        hint: 'Moaboasy74@gmail.com'),
                    const SizedBox(height: 16),
                    _buildTextField(
                        label: 'Blood type',
                        controller: _bloodTypeController,
                        focusNode: _fnBlood,
                        hint: 'O positive'),
                    const SizedBox(height: 16),
                    _buildTextField(
                        label: 'Allergies',
                        controller: _allergiesController,
                        focusNode: _fnAllergy,
                        hint: 'Peanuts'),
                    const SizedBox(height: 16),
                    _buildTextField(
                        label: 'Medical conditions',
                        controller: _medicalConditionsController,
                        focusNode: _fnMedical,
                        hint: 'Asthma , Diabetes'),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Phone Number',
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
                                  _phoneController.text = selectedCode;
                                  _phoneController.selection =
                                      TextSelection.fromPosition(
                                    TextPosition(
                                        offset: _phoneController.text.length),
                                  );
                                });
                              },
                              itemBuilder: (context) => [
                                _buildCountryItem("🇪🇬", "Egypt", "+20"),
                                _buildCountryItem(
                                    "🇸🇦", "Saudi Arabia", "+966"),
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
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  hintText:
                                      _fnPhone.hasFocus ? "" : "+201551471747",
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
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Confirm',
                            style: TextStyle(
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
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF4A80F1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('change profile picture',
                            style: TextStyle(
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
