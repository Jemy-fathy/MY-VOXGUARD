import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../config/colors.dart';
import '../../custom_widgets/custom_button.dart';
import '../../custom_widgets/logo_header.dart';
import '../../screens/auth/emergency_information_screen.dart';

class ConfirmedScreen extends StatelessWidget {
  const ConfirmedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isArabic = context.locale.languageCode == 'ar';
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
              const SizedBox(height: 60),
              const AppLogoHeader(),
              const Spacer(),
              Container(
                width: 343,
                height: 290,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Column(
                  children: [
                    Align(
                      alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
                      child: IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(
                                  Icons.arrow_back, 
                                  color: Colors.black, 
                                  size: 28
                                ),
                              ),
                    ),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: AppColors.logoGradient,
                      ).createShader(bounds),
                      child: Text(
                        "signup_confirmed".tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 35),
                    CustomButton(
                     text: "add_emergency_info".tr(),
                     onPressed: () {
                      Navigator.push(
                       context,
                       MaterialPageRoute(
                       builder: (context) => const EmergencyInformationScreen(),
                       ),
                      );
                     },
                   ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pushNamed(context, '/how_safe'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF375DFB), width: 1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          "skip_for_now".tr(),
                          style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}