import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../config/api_config.dart';

class FacebookLoginScreen extends StatefulWidget {
  const FacebookLoginScreen({super.key});

  @override
  State<FacebookLoginScreen> createState() => _FacebookLoginScreenState();
}

class _FacebookLoginScreenState extends State<FacebookLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _handleLogin() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Mock standard FB user ID derived from the email for consistency
      final String socialId = "fb_${email.hashCode}";
      
      // Clean parsing of first and last name from email prefix
      String emailPrefix = email.split('@').first;
      String firstName = "";
      String lastName = "";
      
      if (emailPrefix.contains('.')) {
        List<String> parts = emailPrefix.split('.');
        firstName = parts.first[0].toUpperCase() + parts.first.substring(1).toLowerCase();
        lastName = parts.last[0].toUpperCase() + parts.last.substring(1).toLowerCase();
      } else {
        firstName = emailPrefix[0].toUpperCase() + emailPrefix.substring(1).toLowerCase();
        lastName = "User";
      }

      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/social-login"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "social_id": socialId,
          "social_type": "facebook",
          "email": email,
          "first_name": firstName,
          "last_name": lastName,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("welcome_message".tr())),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/permissions', (route) => false);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Facebook authentication failed on server")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connection error. Please try again.")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1877F2),
        elevation: 0,
        title: const Text(
          "facebook",
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: -1,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF1877F2)),
                  SizedBox(height: 16),
                  Text(
                    "Checking info...",
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          "Log in to your Facebook account to connect with Vox Guard",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF606770),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: "Mobile number or email address",
                            hintStyle: const TextStyle(color: Color(0xFF8D949E)),
                            filled: true,
                            fillColor: const Color(0xFFF5F6F7),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Color(0xFFCCD0D5)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Color(0xFFCCD0D5)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Color(0xFF1877F2), width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: "Password",
                            hintStyle: const TextStyle(color: Color(0xFF8D949E)),
                            filled: true,
                            fillColor: const Color(0xFFF5F6F7),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: const Color(0xFF8D949E),
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Color(0xFFCCD0D5)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Color(0xFFCCD0D5)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Color(0xFF1877F2), width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1877F2),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            "Log In",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Forgot Password?",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF1877F2),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "English (US)",
                        style: TextStyle(color: Color(0xFF90949C), fontSize: 12),
                      ),
                      SizedBox(width: 8),
                      Text("•", style: TextStyle(color: Color(0xFF90949C))),
                      SizedBox(width: 8),
                      Text(
                        "العربية",
                        style: TextStyle(color: Color(0xFF1877F2), fontSize: 12),
                      ),
                      SizedBox(width: 8),
                      Text("•", style: TextStyle(color: Color(0xFF90949C))),
                      SizedBox(width: 8),
                      Text(
                        "More...",
                        style: TextStyle(color: Color(0xFF1877F2), fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Meta © 2026",
                    style: TextStyle(color: Color(0xFF90949C), fontSize: 12),
                  ),
                ],
              ),
            ),
    );
  }
}
