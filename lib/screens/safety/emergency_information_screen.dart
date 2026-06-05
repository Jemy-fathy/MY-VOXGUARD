import 'package:flutter/material.dart';

class EmergencyInformationScreen extends StatefulWidget {
  const EmergencyInformationScreen({super.key});

  @override
  State<EmergencyInformationScreen> createState() =>
      _EmergencyInformationScreenState();
}

class _EmergencyInformationScreenState
    extends State<EmergencyInformationScreen> {
  final TextEditingController _bloodTypeController =
      TextEditingController(text: 'O positive');
  final TextEditingController _allergiesController =
      TextEditingController(text: 'Peanuts, Penicillin');
  final TextEditingController _medicalConditionsController =
      TextEditingController(text: 'Asthma, Diabetes');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE0EAFC), Color(0xFFE8DBFA), Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'images/logo .png',
                      height: 40,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.shield,
                        color: Color(0xFFD546F3),
                        size: 40,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [
                          Color(0XFF4983F6),
                          Color(0xFFC175F5),
                          Color(0XFFFBACB7)
                        ],
                      ).createShader(bounds),
                      child: const Text(
                        'voxguard',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 90),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Padding(
                          padding: EdgeInsets.all(10.0),
                          child: Icon(Icons.arrow_back,
                              color: Colors.black, size: 26),
                        ),
                      ),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Color(0XFF4983F6),
                            Color(0xFFC175F5),
                            Color(0XFFFBACB7)
                          ],
                        ).createShader(bounds),
                        child: const Center(
                          child: Text(
                            'Emergency information',
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'this information will only be shared with your trusted contacts in an emergency.',
                        style: TextStyle(
                            color: Colors.black, fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 24),

                      // الحقول
                      _buildEditableField('Blood Type', _bloodTypeController),
                      const SizedBox(height: 16),
                      _buildEditableField('Allergies', _allergiesController),
                      const SizedBox(height: 16),
                      _buildEditableField(
                          'Medical conditions', _medicalConditionsController),

                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD546F3),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(
                                  color: Color(0XFF4983F6), width: 2),
                            ),
                          ),
                          child: const Text(
                            'Save',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ),
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

  Widget _buildEditableField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              color: Colors.black, fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.grey, fontSize: 15),
          // هنا الكود اللي بيمسح النص لما تضغط عليه
          onTap: () {
            if (controller.text.isNotEmpty) {
              controller.clear();
            }
          },
          decoration: InputDecoration(
            hintText: 'Enter $label',
            hintStyle: const TextStyle(color: Colors.grey),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            filled: true,
            fillColor: Colors.grey[50],
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD546F3), width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
