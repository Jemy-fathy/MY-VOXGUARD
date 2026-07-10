import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../config/colors.dart';
import '../../custom_widgets/custom_button.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    bool isArabic = context.locale.languageCode == 'ar';
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
        child: Column(
          children: [
            const Spacer(flex: 3),
            Image.asset('images/logo.png', width: 220, fit: BoxFit.contain),
            const SizedBox(height: 15),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: AppColors.logoGradient,
              ).createShader(bounds),
              child: Text(
                isArabic ? "فوكس جارد" : "voxguard",
                style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: 287,
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: AppColors.logoGradient,
                ).createShader(bounds),
                child: Text(
                  "splash_slogan".tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    letterSpacing: -0.6,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const Spacer(flex: 1),
            Padding(
              padding: const EdgeInsets.only(bottom: 60, left: 25, right: 25),
              child: CustomButton(
                text: "start".tr(),
                onPressed: () => Navigator.pushNamed(context, '/login'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}