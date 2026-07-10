import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api_config.dart';
import '../../config/colors.dart';
import '../../custom_widgets/custom_button.dart';
import '../../custom_widgets/logo_header.dart';
import 'signup_confirmed.dart';

class EmergencyInformationScreen extends StatefulWidget {
  const EmergencyInformationScreen({super.key});

  @override
  State<EmergencyInformationScreen> createState() =>
      _EmergencyInformationScreenState();
}

class _EmergencyInformationScreenState
    extends State<EmergencyInformationScreen> {
  final TextEditingController _bloodTypeController = TextEditingController();
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
              // Drag handle
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
                        setSheetState(() => tempSelected = item);
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

  Future<void> _saveEmergencyInfo() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        print("DEBUG: Token is null!");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('token_missing'.tr())),
        );
        return;
      }

      print("DEBUG: Saving emergency info with token: $token");
      final response = await http.post(
        Uri.parse(ApiConfig.updateEmergencyInfo),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'blood_type': _bloodTypeController.text,
          'allergies': _selectedAllergies.join(', '),
          'medical_conditions': _selectedMedicalConditions.join(', '),
        }),
      );

      print("DEBUG: Status Code: ${response.statusCode}");
      print("DEBUG: Response Body: ${response.body}");

      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SignUpConfirmedScreen()),
        );
      } else {
        if (!mounted) return;
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorData['message'] ?? 'failed_to_save'.tr())),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('error_occurred'.tr())),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.bgBlueLight,
              AppColors.bgPurpleLight,
              Colors.white,
            ],
            stops: [0.0, 0.3, 0.7],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 30),
                const AppLogoHeader(),
                const SizedBox(height: 30),

                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
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
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.black,
                          size: 28,
                        ),
                      ),

                      Center(
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: AppColors.logoGradient,
                          ).createShader(bounds),
                          child: Text(
                            'emergency_info'.tr(),
                            style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),
                      Text(
                        'emergency_info_desc'.tr(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 16),

                      _buildSelectionField(
                        label: 'blood_type'.tr(),
                        value: _bloodTypeController.text.isNotEmpty
                            ? _bloodTypeController.text.tr()
                            : '',
                        hint: 'o_positive'.tr(),
                        onTap: _showBloodTypeBottomSheet,
                      ),
                      const SizedBox(height: 16),
                      _buildSelectionField(
                        label: 'allergies'.tr(),
                        value: _selectedAllergies.isEmpty
                            ? ''
                            : _selectedAllergies.map((e) => e.tr()).join(', '),
                        hint: 'peanuts_penicillin_hint'.tr(),
                        onTap: () => _showMultiSelectBottomSheet(
                          title: 'Select Allergies'.tr(),
                          options: _allergyOptions,
                          selected: _selectedAllergies,
                          onConfirm: (list) => setState(() => _selectedAllergies = list),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSelectionField(
                        label: 'medical_conditions'.tr(),
                        value: _selectedMedicalConditions.isEmpty
                            ? ''
                            : _selectedMedicalConditions.map((e) => e.tr()).join(', '),
                        hint: 'asthma_diabetes_hint'.tr(),
                        onTap: () => _showMultiSelectBottomSheet(
                          title: 'Select Medical Conditions'.tr(),
                          options: _medicalConditionOptions,
                          selected: _selectedMedicalConditions,
                          onConfirm: (list) => setState(() => _selectedMedicalConditions = list),
                        ),
                      ),

                      const SizedBox(height: 24),

                      _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primaryPurple,
                              ),
                            )
                          : CustomButton(
                              text: 'save'.tr(),
                              onPressed: _saveEmergencyInfo,
                            ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
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
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFFBFBFB),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value.isEmpty ? hint : value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: value.isEmpty ? Colors.grey.shade400 : Colors.black,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
