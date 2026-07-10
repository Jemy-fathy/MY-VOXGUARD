import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
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
              _buildStepper(0),
              const SizedBox(height: 25),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: AppColors.logoGradient,
                ).createShader(bounds),
                child: Text(
                  "how_we_keep_safe".tr(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 46),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    FeatureInfoCard(
                      title: "sos_alert".tr(),
                      description: "sos_alert_desc".tr(),
                      icon: Icons.sos,
                    ),
                    FeatureInfoCard(
                      title: "voice_password".tr(),
                      description: "voice_password_alert_desc".tr(),
                      icon: Icons.mic,
                    ),
                    FeatureInfoCard(
                      title: "fake_call".tr(),
                      description: "fake_call_desc".tr(),
                      icon: Icons.phone,
                    ),
                    FeatureInfoCard(
                      title: "trip_tracking".tr(),
                      description: "trip_tracking_desc".tr(),
                      icon: Icons.location_on,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: CustomButton(
                  text: "continue".tr(),
                  onPressed: () => Navigator.pushNamed(context, '/permissions'),
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
      children: List.generate(
        4,
        (index) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: index == activeStep ? 9.7 : 9.7,
          height: 10,
          decoration: BoxDecoration(
            color: index == activeStep
                ? const Color(0xFFCB30E0)
                : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
      ),
    );
  }
}
