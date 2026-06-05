import 'package:flutter/material.dart';
import '../../config/colors.dart';
import '../../custom_widgets/custom_button.dart';
import '../../custom_widgets/logo_header.dart';
import '../voice_password/voice_password_intro_screen.dart';

class AddTrustedContactsScreen extends StatelessWidget {
  const AddTrustedContactsScreen({super.key});

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
              _buildStepper(2),
              const Spacer(),
              _buildCentralIcon(),
              const SizedBox(height: 40),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: AppColors.logoGradient,
                ).createShader(bounds),
                child: const SizedBox(
                  width: 336,
                  height: 34,
                  child: Text(
                    "Add your trusted contacts",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const SizedBox(
                width: 386,
                height: 173,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    "Add Trusted Friends and Family to your Private Safe Circle. They Will be Instantly Notified With Your Location If You Ever Need Help.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      height: 1.5,
                    ),
                  ),
                ),
              ),

Padding(
  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
  child: Column(
    children: [
      CustomButton(
        text: "Add trusted contacts",
        onPressed: () => Navigator.pushNamed(context, '/add_contact'),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const VoicePasswordIntroScreen(),
              ),
            );
          },
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF4983F6)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            "Skip for now",
            style: TextStyle(color: Colors.black, fontSize: 16),
          ),
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

  Widget _buildStepper(int activeStep) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 9.7,
        height: 10,
        decoration: BoxDecoration(
          color: index == activeStep ? const Color(0xFFCB30E0) : const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(5),
        ),
      )),
    );
  }

  Widget _buildCentralIcon() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFD77EF5).withOpacity(0.15),
          ),
        ),
        Container(
          width: 144,
          height: 144,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFD77EF5).withOpacity(0.3),
          ),
        ),
        Container(
          width: 108,
          height: 108,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xD4D77EF5),
          ),
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  color: Color(0xFFEA3EF7),
                  size: 50,
                ),
                Positioned(
                  top: 19, 
                  child: Icon(
                    Icons.favorite,
                    color: const Color(0xFFEA3EF7),
                    size: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}