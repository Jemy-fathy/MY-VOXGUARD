import 'package:flutter/material.dart';
import '../../config/colors.dart';
import '../../custom_widgets/custom_button.dart';
import '../../custom_widgets/logo_header.dart';
import '../../custom_widgets/feature_info_card.dart';

class HowWeKeepSafeScreen extends StatelessWidget {
  const HowWeKeepSafeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.bgBlueLight, AppColors.bgPurpleLight, Colors.white],
            stops: const [0.0, 0.3, 0.7],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              const AppLogoHeader(),
              const SizedBox(height: 15),
              _buildStepper(0), 
              const SizedBox(height: 25),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: AppColors.logoGradient,
                ).createShader(bounds),
                child: const Text(
                  "How we keep you safe ?",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: const [
                    FeatureInfoCard(
                      title: "SOS Alert", 
                      description: "Instantly send an emergency alert to your trusted contactes with your location.", 
                      icon: Icons.sos
                    ),
                    FeatureInfoCard(
                      title: "Voice Password", 
                      description: "Activate alerts hands-free by speaking your secret phrase, even from a distance.", 
                      icon: Icons.mic
                    ),
                    FeatureInfoCard(
                      title: "Fake Call", 
                      description: "Discreetly simulate an incoming phone call to create a diversion and exit unsafe situations.", 
                      icon: Icons.phone
                    ),
                    FeatureInfoCard(
                      title: "Trip Tracking", 
                      description: "Share your live journey with friends or family so they know you've arrived safely.", 
                      icon: Icons.location_on
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: CustomButton(
                  text: "Continue", 
                  onPressed: () => Navigator.pushNamed(context, '/permissions')
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
        width: index == activeStep ? 9.7 : 9.7,
        height: 10,
        decoration: BoxDecoration(
          color: index == activeStep ? const Color(0xFFCB30E0) : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(5),
        ),
      )),
    );
  }
}