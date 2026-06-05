import 'package:flutter/material.dart';
import '../../config/colors.dart';
import '../../custom_widgets/custom_button.dart';
import '../../custom_widgets/logo_header.dart';
import '../voice_password/voice_password_intro_screen.dart'; 

class ContactAddedScreen extends StatelessWidget {
  const ContactAddedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.bgBlueLight,
              AppColors.bgPurpleLight,
              Colors.white,
            ],
            stops: const [0.0, 0.3, 0.7],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              const AppLogoHeader(),
              const SizedBox(height: 15),
              _buildStepper(3),
              const Spacer(),
              Container(
                width: 144,
                height: 144,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFD77EF5).withOpacity(0.4),
                ),
                child: const Icon(
                  Icons.person_add_alt_1_outlined,
                  color: Color(0xFFEA3EF7),
                  size: 80,
                ),
              ),
              const SizedBox(height: 40),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: AppColors.logoGradient,
                ).createShader(bounds),
                child: const SizedBox(
                  width: 363,
                  height: 34,
                  child: Text(
                    "Contact Added",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 100),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Column(
                  children: [
                    CustomButton(
                      text: "Confirm",
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const VoicePasswordIntroScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF375DFB)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          "add another one",
                          style: TextStyle(
                            color: Colors.black, 
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepper(int activeStep) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 9.7,
        height: 10,
        decoration: BoxDecoration(
          color: index == activeStep ? const Color(0xFFCB30E0) : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(5),
        ),
      )),
    );
  }
}