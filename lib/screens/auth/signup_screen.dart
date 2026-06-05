import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl_phone_field/intl_phone_field.dart';
import '../../config/colors.dart';
import '../../custom_widgets/custom_button.dart';
import '../../custom_widgets/custom_text_field.dart';
import '../../custom_widgets/logo_header.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  String phoneNumber = "";
  bool isLoading = false;

  void showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> registerUser() async {
   
    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (firstName.isEmpty || lastName.isEmpty || email.isEmpty || phoneNumber.isEmpty || password.isEmpty) {
      showSnackBar("Please fill all fields");
      return;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      showSnackBar("Please enter a valid email address");
      return;
    }

    if (password.length < 8) {
      showSnackBar("Password must be at least 8 characters");
      return;
    }

    if (password != confirmPassword) {
      showSnackBar("Passwords do not match");
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("http://192.168.1.191:8000/api/register"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "first_name": firstName,
          "last_name": lastName,
          "email": email,
          "phone_number": phoneNumber,
          "password": password,
          "password_confirmation": confirmPassword
        }),
      );

      if (!mounted) return;
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        showSnackBar("Account created successfully!", isError: false);
        Navigator.pushNamed(context, '/confirmed');
      } 
      else if (response.statusCode == 422) {
       
        String errorMessage = "Registration failed";
        if (data["errors"] != null) {
        
          var firstError = data["errors"].values.first;
          errorMessage = firstError is List ? firstError.first : firstError.toString();
        }
        showSnackBar(errorMessage);
      } 
      else {
        showSnackBar(data["message"] ?? "Something went wrong");
      }
    } catch (e) {
      showSnackBar("Connection Error: Make sure your server is running");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
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
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              const AppLogoHeader(),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Container(
                      width: 343,
                      padding: const EdgeInsets.all(24),
                      margin: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                          )
                        ],
                      ),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back),
                            ),
                          ),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: AppColors.logoGradient,
                            ).createShader(bounds),
                            child: const Text(
                              "Sign Up",
                              style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Already have an account? ", style: TextStyle(fontSize: 13)),
                              GestureDetector(
                                onTap: () => Navigator.pushNamed(context, '/login'),
                                child: const Text(
                                  "Login",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryPurple,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: CustomTextField(
                                  controller: firstNameController,
                                  label: "First Name",
                                  hintText: "First",
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: CustomTextField(
                                  controller: lastNameController,
                                  label: "Last Name",
                                  hintText: "Last",
                                ),
                              ),
                            ],
                          ),
                          CustomTextField(
                            controller: emailController,
                            label: "Email",
                            hintText: "Enter your email",
                          ),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text("Phone Number", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          ),
                          const SizedBox(height: 8),
                          IntlPhoneField(
                            initialCountryCode: 'EG',
                            onChanged: (phone) => phoneNumber = phone.completeNumber,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          CustomTextField(
                            controller: passwordController,
                            label: "Set Password",
                            isPassword: true,
                          ),
                          CustomTextField(
                            controller: confirmPasswordController,
                            label: "Confirm Password",
                            isPassword: true,
                          ),
                          const SizedBox(height: 30),
                          isLoading
                              ? const CircularProgressIndicator()
                              : CustomButton(
                                  text: "Register",
                                  onPressed: registerUser,
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}