import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
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
    clientId: '937671622047-1h87v3mvu4k9i32gc2ouegneu4mpiqf3.apps.googleusercontent.com',
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
    if (emailController.text.trim().isEmpty || passwordController.text.isEmpty) {
      _showMessage("Please fill all fields");
      return;
    }

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

        if (data['token'] != null) {
          // تغيير المفتاح هنا أيضاً إلى auth_token
          await prefs.setString('auth_token', data['token']);
        }
        
        // ... (بقية كود حفظ بيانات المستخدم كما هي)

        // --- التعديل هنا: حفظ بيانات المستخدم بالكامل ---
        if (data['user'] != null) {
          var user = data['user'];
          
          // حل مشكلة الـ ID إذا كان Null ومنع توقف الكود
          String userId = (user['id'] ?? 0).toString();
          String firstName = user['first_name'] ?? "";
          String lastName = user['last_name'] ?? "";
          String fullName = "$firstName $lastName".trim();
          String profilePic = user['profile_photo_url'] ?? "";

          // استخدام await لضمان الحفظ قبل الانتقال
          await prefs.setString('user_id', userId);
          await prefs.setString('user_name', fullName.isNotEmpty ? fullName : "User");
          await prefs.setString('user_image', profilePic);
          
          dev.log("Success: Saved User -> $fullName");
        }

        if (!mounted) return;
        _showMessage("Welcome back!");
        
        // استخدام pushNamedAndRemoveUntil لضمان تحديث الـ Home
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      } else {
        _showMessage(data["message"] ?? "Invalid credentials");
      }
    } catch (e) {
      dev.log("Login Error: $e");
      _showMessage("Server connection failed. Please check your IP.");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> signInWithGoogle() async {
    setState(() => isLoading = true);
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser != null) {
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } catch (error) {
      _showMessage("Google Error: $error");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> signInWithFacebook() async {
    setState(() => isLoading = true);
    try {
      final result = await FacebookAuth.instance.login();
      if (result.status == LoginStatus.success) {
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      } else {
        _showMessage("Facebook Login ${result.status.toString().split('.').last}");
      }
    } catch (e) {
      _showMessage("Facebook Sign-In failed");
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
    // بناء الـ UI (نفس الكود الخاص بكِ تماماً دون أي تغيير)
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
                        _socialButton("Sign in with Facebook", 'images/facebook_icon.png', isLoading ? null : signInWithFacebook),
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