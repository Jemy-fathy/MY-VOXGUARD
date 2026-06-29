import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../config/colors.dart';
import '../../custom_widgets/custom_button.dart';
import '../../custom_widgets/custom_text_field.dart';
import '../../custom_widgets/logo_header.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  
  bool isRememberMe = false;
  bool isLoading = false;
  bool isPasswordVisible = false; 

  static const String baseUrl = "http://192.168.1.191:8000/api";

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  @override
  void initState() {
    super.initState();
    _checkRememberedUser();
  }

  Future<void> _checkRememberedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token'); 
    if (token != null) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> loginUser() async {
    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/login"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "email_or_phone": emailController.text.trim(),
          "password": passwordController.text,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        if (data['token'] != null) await prefs.setString('auth_token', data['token']);
        
        if (data['user'] != null) {
          var user = data['user'];
          await prefs.setString('user_id', (user['id'] ?? 0).toString());
          await prefs.setString('user_name', "${user['first_name'] ?? ''} ${user['last_name'] ?? ''}".trim());
          await prefs.setString('user_image', user['profile_photo_url'] ?? "");
        }

        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      } else {
        _showMessage(data["message"] ?? "Invalid credentials");
      }
    } catch (e) {
      dev.log("Login Error: $e");
      _showMessage("Server connection failed.");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

Future<void> signInWithGoogle() async {
  setState(() => isLoading = true);
  try {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      setState(() => isLoading = false);
      return;
    }

    final response = await http.post(
      Uri.parse("$baseUrl/social-login"), 
      headers: {"Content-Type": "application/json", "Accept": "application/json"},
      body: jsonEncode({
        "social_id": googleUser.id,
        "social_type": "google",
        "email": googleUser.email,
        "first_name": googleUser.displayName?.split(' ').first ?? "",
        "last_name": googleUser.displayName?.split(' ').last ?? "",
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString('auth_token', data['token']);
      
      if (data['user'] != null) {
        var user = data['user'];
        await prefs.setString('user_name', "${user['first_name'] ?? ''} ${user['last_name'] ?? ''}".trim());
      }
      
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/permissions', (route) => false);
    } else {
    }
  } catch (error) {
    dev.log("Google Sign In Error: $error");
  } finally {
    if (mounted) setState(() => isLoading = false);
  }
}

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
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
        child: Column(
          children: [
            const SizedBox(height: 60),
            const AppLogoHeader(),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildGradientTitle(),
                        const SizedBox(height: 8),
                        const Text(
                          "Create an account or log in to explore our app",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 25),
                        _socialButton("Sign in with Google", 'images/google_icon.png', isLoading ? null : signInWithGoogle),
                        const SizedBox(height: 12),
                        const SizedBox(height: 20),
                        _buildDivider(),
                        const SizedBox(height: 20),
                        CustomTextField(
                          controller: emailController,
                          label: "Email or Phone",
                          hintText: "Enter your email or phone",
                        ),
                        _buildPasswordField(),
                        _buildRememberMeRow(),
                        const SizedBox(height: 30),
                        isLoading
                            ? const CircularProgressIndicator(color: AppColors.primaryPurple)
                            : CustomButton(text: "Log In", onPressed: loginUser),
                        const SizedBox(height: 20),
                        _buildSignUpRow(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientTitle() {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(colors: AppColors.logoGradient).createShader(bounds),
      child: const Text("Get Started now", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }

  Widget _buildDivider() {
    return const Row(
      children: [
        Expanded(child: Divider()),
        Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("Or", style: TextStyle(color: Colors.grey))),
        Expanded(child: Divider()),
      ],
    );
  }

  Widget _buildPasswordField() {
    return CustomTextField(
      controller: passwordController,
      label: "Password",
      isPassword: !isPasswordVisible,
    );
  }

  Widget _buildRememberMeRow() {
    return Row(
      children: [
        SizedBox(
          width: 24, height: 24,
          child: Checkbox(
            value: isRememberMe,
            activeColor: AppColors.primaryPurple,
            onChanged: (v) => setState(() => isRememberMe = v!),
          ),
        ),
        const SizedBox(width: 8),
        const Text("Remember me", style: TextStyle(fontSize: 12)),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/forgot_password'),
          child: const Text("Forgot Password ?", style: TextStyle(fontSize: 12, color: AppColors.primaryPurple, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildSignUpRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Don't have an account? "),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/signup'),
          child: const Text("Sign Up", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryPurple)),
        ),
      ],
    );
  }

  Widget _socialButton(String label, String iconPath, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1.0,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(iconPath, width: 24, height: 24, errorBuilder: (c, e, s) => const Icon(Icons.error)),
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}