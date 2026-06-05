import 'package:flutter/material.dart';
import 'colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      fontFamily: 'Inter',
      scaffoldBackgroundColor: Colors.white,
      primaryColor: AppColors.primaryPurple,
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primaryPurple;
          return Colors.transparent;
        }),
      ),
      dividerTheme: const DividerThemeData(
        thickness: 1,
        color: Color(0xFFE0E0E0),
      ),
    );
  }
}