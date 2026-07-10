import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'facebook_login_screen.dart';
import '../../config/api_config.dart';
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

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '937671622047-1h87v3mvu4k9i32gc2ouegneu4mpiqf3.apps.googleusercontent.com',
    scopes: ['email', 'profile'],
  );

  @override
  void initState() {
    super.initState();
    _checkRememberedUser();
  }

  Future<void> _checkRememberedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? prefs.getString('auth_token');
    if (token != null) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  void _showMessage(String message, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        action: action,
      ),
    );
  }

  void _showChangeIpDialog(BuildContext context) {
    final TextEditingController ipController = TextEditingController(text: ApiConfig.serverIp);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تغيير عنوان السيرفر (Server IP)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('أدخل عنوان الـ IP الخاص بجهاز الـ Mac حالياً:'),
            const SizedBox(height: 12),
            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                hintText: 'مثال: 192.168.1.29',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              String newIp = ipController.text.trim();
              if (newIp.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('custom_server_ip', newIp);
                ApiConfig.setServerIp(newIp);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('تم تحديث الـ IP إلى: $newIp. يرجى المحاولة مجدداً.')),
                  );
                }
              }
            },
            child: const Text('حفظ وتحديث'),
          ),
        ],
      ),
    );
  }

  Future<void> loginUser({bool isRetry = false}) async {
    if (emailController.text.trim().isEmpty || passwordController.text.isEmpty) {
      _showMessage("please_fill_fields".tr());
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.login),
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
          await prefs.setString('token', data['token']);
          await prefs.setString('auth_token', data['token']); 
        }

        if (data['user'] != null) {
          var user = data['user'];
          if (user['id'] != null) {
            String userId = user['id'].toString();
            await prefs.setString('user_id', userId);
            dev.log("Success: Logged in as User ID: $userId");
          }
          if (user['first_name'] != null) {
            await prefs.setString('first_name', user['first_name']);
          }
          if (user['last_name'] != null) {
            await prefs.setString('last_name', user['last_name']);
          }
          String name = "${user['first_name'] ?? ''} ${user['last_name'] ?? ''}".trim();
          await prefs.setString('user_name', name);
          await prefs.setString('user_image', user['profile_photo_url'] ?? "");
        }

        if (!mounted) return;
        _showMessage("welcome_message".tr());
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        _showMessage(data["message"] ?? "invalid_credentials".tr());
      }
    } catch (e) {
      dev.log("Login Error: $e");
      if (!mounted) return;
      
      if (!isRetry) {
        // Show a temporary dialog while we search the network for the server
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('جاري البحث التلقائي عن السيرفر في الشبكة...'),
                  ],
                ),
              ),
            ),
          ),
        );
        
        String? foundIp = await ApiConfig.autoDiscoverServer();
        if (context.mounted) Navigator.pop(context);
        
        if (foundIp != null) {
          // Retry login with the newly found IP address
          await loginUser(isRetry: true);
          return;
        }
      }

      _showMessage(
        "server_error".tr(),
        action: SnackBarAction(
          label: 'تحديث الـ IP',
          textColor: Colors.white,
          onPressed: () => _showChangeIpDialog(context),
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- تسجيل الدخول بجوجل ---
  Future<void> signInWithGoogle() async {
    // iOS simulators lack GoogleService-Info.plist, so we bypass Safari oauth screen which blocks access
    if (Platform.isIOS) {
      _showDemoGoogleDialog();
      return;
    }

    setState(() => isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => isLoading = false);
        return;
      }

      await _sendSocialLogin(
        socialId: googleUser.id,
        socialType: "google",
        email: googleUser.email,
        name: googleUser.displayName ?? "",
      );
    } catch (error) {
      dev.log("Google Sign In Error (using fallback): $error");
      if (!mounted) return;
      _showDemoGoogleDialog();
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- تسجيل الدخول بفيسبوك ---
  Future<void> signInWithFacebook() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FacebookLoginScreen()),
    );
  }

  Future<void> _sendSocialLogin({
    required String socialId,
    required String socialType,
    required String email,
    required String name,
  }) async {
    final response = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/social-login"),
      headers: {"Content-Type": "application/json", "Accept": "application/json"},
      body: jsonEncode({
        "social_id": socialId,
        "social_type": socialType,
        "email": email.isNotEmpty ? email : "$socialId@demo.com",
        "first_name": name.isNotEmpty ? name.split(' ').first : "Demo",
        "last_name": name.split(' ').length > 1 ? name.split(' ').last : "User",
      }),
    ).timeout(const Duration(seconds: 10));

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final prefs = await SharedPreferences.getInstance();
      if (data['token'] != null) {
        await prefs.setString('token', data['token']);
        await prefs.setString('auth_token', data['token']);
      }
      if (data['user'] != null) {
        var user = data['user'];
        await prefs.setString('user_id', (user['id'] ?? 0).toString());
        if (user['first_name'] != null) {
          await prefs.setString('first_name', user['first_name'].toString());
        }
        if (user['last_name'] != null) {
          await prefs.setString('last_name', user['last_name'].toString());
        }
        if (user['email'] != null) {
          await prefs.setString('email', user['email'].toString());
        }
        String displayName = "${user['first_name'] ?? ''} ${user['last_name'] ?? ''}".trim();
        displayName = displayName.replaceAll('FacebookUser', '').trim();
        if (displayName.endsWith('.')) {
          displayName = displayName.substring(0, displayName.length - 1).trim();
        }
        await prefs.setString('user_name', displayName);
        await prefs.setString('user_image', user['profile_photo_url'] ?? "");
      }
      if (!mounted) return;
      _showMessage("welcome_message".tr());
      Navigator.pushNamedAndRemoveUntil(context, '/permissions', (route) => false);
    } else {
      _showMessage("Social Sign-In failed on backend");
    }
  }

  void _showDemoFacebookDialog() {
    final TextEditingController nameController = TextEditingController(text: "Facebook DemoUser");
    final TextEditingController emailController = TextEditingController(text: "demo_facebook_user@gmail.com");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Facebook Sign-In (Demo/Test)"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Facebook Sign-In is using development demo mode. Enter any test credentials:"),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "الاسم (Name)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: "البريد الإلكتروني (Email)",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("cancel".tr()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple),
            onPressed: () async {
              String name = nameController.text.trim();
              String email = emailController.text.trim();
              if (name.isEmpty || email.isEmpty) {
                _showMessage("الرجاء إدخال الاسم والبريد الإلكتروني");
                return;
              }
              Navigator.pop(context);
              setState(() => isLoading = true);
              try {
                String cleanEmail = email.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
                String socialId = "${cleanEmail}_facebook_demo";

                await _sendSocialLogin(
                  socialId: socialId,
                  socialType: "facebook",
                  email: email,
                  name: name,
                );
              } catch (e) {
                _showMessage("Connection error");
              } finally {
                if (mounted) setState(() => isLoading = false);
              }
            },
            child: Text("login".tr()),
          ),
        ],
      ),
    );
  }

  void _showDemoGoogleDialog() {
    final TextEditingController nameController = TextEditingController(text: "Google DemoUser");
    final TextEditingController emailController = TextEditingController(text: "demo_google_user@gmail.com");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Google Sign-In (Demo/Test)"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Google Sign-In is using development demo mode. Enter any test credentials:"),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "الاسم (Name)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: "البريد الإلكتروني (Email)",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("cancel".tr()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple),
            onPressed: () async {
              String name = nameController.text.trim();
              String email = emailController.text.trim();
              if (name.isEmpty || email.isEmpty) {
                _showMessage("الرجاء إدخال الاسم والبريد الإلكتروني");
                return;
              }
              Navigator.pop(context);
              setState(() => isLoading = true);
              try {
                String cleanEmail = email.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
                String socialId = "${cleanEmail}_google_demo";

                await _sendSocialLogin(
                  socialId: socialId,
                  socialType: "google",
                  email: email,
                  name: name,
                );
              } catch (e) {
                _showMessage("Connection error");
              } finally {
                if (mounted) setState(() => isLoading = false);
              }
            },
            child: Text("login".tr()),
          ),
        ],
      ),
    );
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
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Language Switcher
                    TextButton.icon(
                      onPressed: () async {
                        if (context.locale.languageCode == 'ar') {
                          await context.setLocale(const Locale('en'));
                        } else {
                          await context.setLocale(const Locale('ar'));
                        }
                      },
                      icon: const Icon(Icons.language, color: AppColors.primaryPurple),
                      label: Text(
                        context.locale.languageCode == 'ar' ? "العربية" : "English",
                        style: const TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
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
                        Text(
                          "login_subtitle".tr(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 25),
                        _socialButton("sign_in_google".tr(), 'images/google_icon.png', isLoading ? null : signInWithGoogle),
                        const SizedBox(height: 12),
                        _socialButton("sign_in_facebook".tr(), 'images/facebook_icon.png', isLoading ? null : signInWithFacebook),
                        const SizedBox(height: 20),
                        _buildDivider(),
                        const SizedBox(height: 20),
                        CustomTextField(
                          controller: emailController,
                          label: "email_phone".tr(),
                          hintText: "enter_email_phone".tr(),
                        ),
                        _buildPasswordField(),
                        _buildRememberMeRow(),
                        const SizedBox(height: 30),
                        isLoading
                            ? const CircularProgressIndicator(color: AppColors.primaryPurple)
                            : CustomButton(text: "login".tr(), onPressed: loginUser),
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
      child: Text("get_started_now".tr(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }

  Widget  _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text("or".tr(), style: const TextStyle(color: Colors.grey))),
        const Expanded(child: Divider()),
      ],
    );
  }

  Widget _buildPasswordField() {
    return CustomTextField(
      controller: passwordController,
      label: "password".tr(),
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
        Text("remember_me".tr(), style: const TextStyle(fontSize: 12)),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/forgot_password'),
          child: Text("forgot_password".tr(), style: const TextStyle(fontSize: 12, color: AppColors.primaryPurple, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildSignUpRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("${"dont_have_account".tr()} "),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/signup'),
          child: Text("sign_up".tr(), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryPurple)),
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
