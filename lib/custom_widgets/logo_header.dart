import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../config/colors.dart';

class AppLogoHeader extends StatelessWidget {
  const AppLogoHeader({super.key});

  @override
  Widget build(BuildContext context) {
    bool isArabic = context.locale.languageCode == 'ar';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'images/logo.png',
          width: 33,
          height: 42,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 10),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: AppColors.logoGradient,
          ).createShader(bounds),
          child: Text(
            isArabic ? "فوكس جارد" : "voxguard",
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}