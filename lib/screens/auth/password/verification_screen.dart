import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;
import 'package:vox_guard/custom_widgets/logo_header.dart';
import '../../../config/colors.dart';
import '../../../config/api_config.dart';
import 'change_password_screen.dart';

class VerificationScreen extends StatefulWidget {
  final String emailOrPhone;
  const VerificationScreen({super.key, required this.emailOrPhone});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = false;
  bool _hasError = false; // ← لما الكود غلط

  // Shake animation
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: -5), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -5, end: 0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeInOut,
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  String _localizeDigits(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < english.length; i++) {
      input = input.replaceAll(english[i], arabic[i]);
    }
    return input;
  }

  String _normalizeArabicDigits(String input) {
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    for (int i = 0; i < arabic.length; i++) {
      input = input.replaceAll(arabic[i], english[i]);
    }
    return input;
  }

  Future<void> _verifyCode() async {
    final rawCode = _codeController.text.trim();
    final code = _normalizeArabicDigits(rawCode);
    if (code.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter the code'.tr())),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ChangePasswordScreen(
          emailOrPhone: _normalizeArabicDigits(widget.emailOrPhone),
          code: code,
        ),
      ),
    );
  }

  Future<void> _resendCode() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    _codeController.clear();
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.forgotPassword),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email_or_phone': widget.emailOrPhone}),
      );

      setState(() {
        _isLoading = false;
      });
      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Code resent successfully!'.tr())),
        );
      } else {
        String errorMessage = 'Failed to resend code'.tr();
        try {
          final responseData = jsonDecode(response.body);
          if (responseData['message'] != null) {
            errorMessage = responseData['message'];
          }
        } catch (_) {}
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error. Please try again later.'.tr())),
      );
    }
  }

  /// ← المربعات العادية لما الكود صح أو لسه بيكتب
  Widget _buildOtpBoxes() {
    String code = _codeController.text;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(4, (index) {
        bool isFocused = _focusNode.hasFocus && code.length == index;
        bool isFilled = code.length > index;
        String digit = isFilled ? code[index] : '';

        return GestureDetector(
          onTap: () => _focusNode.requestFocus(),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 1.0, end: isFocused ? 1.08 : 1.0),
            duration: const Duration(milliseconds: 150),
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: isFocused
                          ? AppColors.primaryPurple
                          : (isFilled
                              ? AppColors.primaryPurple.withOpacity(0.5)
                              : Colors.grey.shade300),
                      width: isFocused ? 2.5 : 1.5,
                    ),
                    boxShadow: isFocused
                        ? [
                            BoxShadow(
                              color: AppColors.primaryPurple.withOpacity(0.3),
                              blurRadius: 10,
                              spreadRadius: 2,
                            )
                          ]
                        : (isFilled
                            ? [
                                BoxShadow(
                                  color:
                                      AppColors.primaryPurple.withOpacity(0.08),
                                  blurRadius: 5,
                                )
                              ]
                            : []),
                  ),
                  alignment: Alignment.center,
                  child: isFocused && digit.isEmpty
                      ? const BlinkingCursor()
                      : Text(
                          context.locale.languageCode == 'ar'
                              ? _localizeDigits(digit)
                              : digit,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                ),
              );
            },
          ),
        );
      }),
    );
  }

  /// ← المربع الأحمر الواحد لما الكود غلط
  Widget _buildErrorBox() {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: child,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.red.shade400, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.25),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade500, size: 20),
            const SizedBox(width: 8),
            Text(
              'wrong_code'.tr(),
              style: TextStyle(
                color: Colors.red.shade600,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isArabic = context.locale.languageCode == 'ar';
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
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
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 20.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const AppLogoHeader(),
                  const SizedBox(height: 40),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Align(
                          alignment: isArabic
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.black,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: AppColors.logoGradient,
                          ).createShader(bounds),
                          child: Text(
                            'Forgot password'.tr(),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // ← هنا بيتغير بين المربعات والمربع الأحمر
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Opacity(
                              opacity: 0.0,
                              child: SizedBox(
                                height: 50,
                                width: 250,
                                child: TextField(
                                  controller: _codeController,
                                  focusNode: _focusNode,
                                  keyboardType: TextInputType.number,
                                  maxLength: 4,
                                  onChanged: (value) {
                                    setState(() {
                                      _hasError = false;
                                    });
                                    if (value.length == 4) {
                                      _verifyCode();
                                    }
                                  },
                                  decoration: const InputDecoration(
                                    counterText: "",
                                  ),
                                ),
                              ),
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: _hasError
                                  ? _buildErrorBox()
                                  : _buildOtpBoxes(),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        TextButton(
                          onPressed: _isLoading ? null : _resendCode,
                          child: Text(
                            'Resend'.tr(),
                            style: const TextStyle(
                              color: AppColors.primaryPurple,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),
                        Text(
                          'This code will expire 10 minutes after this message. If you don\'t get a message.'
                              .tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _verifyCode,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryPurple,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(
                                  color: AppColors.buttonBorderBlue,
                                  width: 1.0,
                                ),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'Change password'.tr(),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
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
        ),
      ),
    );
  }
}

class BlinkingCursor extends StatefulWidget {
  const BlinkingCursor({super.key});

  @override
  State<BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 2,
        height: 22,
        color: AppColors.primaryPurple,
      ),
    );
  }
}
