import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../../config/colors.dart';
import '../../custom_widgets/custom_button.dart';
import '../../custom_widgets/custom_text_field.dart';
import '../../custom_widgets/logo_header.dart';
import 'contact_added_screen.dart'; 

class AddContactScreen extends StatefulWidget {
  const AddContactScreen({super.key});

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController relationController = TextEditingController();
  String fullPhoneNumber = "";
  
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  final String apiUrl = "http://192.168.1.191:8000/api/trusted-contacts/store";

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  Future<void> _saveContact() async {
    FocusScope.of(context).unfocus();

    if (firstNameController.text.isEmpty || fullPhoneNumber.isEmpty || relationController.text.isEmpty) {
      _showSnackBar("Please fill all required fields", Colors.orange);
      return;
    }

    _showLoadingDialog();

    try {
      final prefs = await SharedPreferences.getInstance();
      
      String token = prefs.getString('auth_token') ?? "";

      print("========= VOXGUARD AUTH CHECK =========");
      print("Token found: ${token.isNotEmpty ? "YES (Valid Layout)" : "NO (Empty)"}");
      print("=======================================");

      if (token.isEmpty) {
        if (mounted) Navigator.pop(context);
        _showSnackBar("Session expired. Please login again.", Colors.red);
        return;
      }

      Map<String, dynamic> fields = {
        "name": "${firstNameController.text} ${lastNameController.text}".trim(),
        "phone": fullPhoneNumber,
        "relation": relationController.text,
        "is_online": 0,
        "status": "offline",
      };

      if (_selectedImage != null) {
        fields["image"] = await MultipartFile.fromFile(
          _selectedImage!.path,
          filename: _selectedImage!.path.split('/').last,
        );
      }

      FormData formData = FormData.fromMap(fields);

      var dio = Dio();
      var response = await dio.post(
        apiUrl,
        data: formData,
        options: Options(
          headers: {
            "Accept": "application/json",
            "Authorization": "Bearer $token",
          },
          validateStatus: (status) => status != null && status <= 500,
        ),
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const ContactAddedScreen()),
          (route) => route.isFirst, 
        );
      } else {
        String errorMsg = "Save failed";
        if (response.data != null && response.data['message'] != null) {
          errorMsg = response.data['message'];
        } else if (response.data != null && response.data['errors'] != null) {
          errorMsg = response.data['errors'].toString();
        }
        _showSnackBar(errorMsg, Colors.red);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnackBar("Connection Error. Check your server.", Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating)
    );
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple))
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
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
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  const AppLogoHeader(),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10))
                      ],
                    ),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back)
                          ),
                        ),
                        _buildGradientTitle(),
                        const SizedBox(height: 25),
                        Row(
                          children: [
                            Expanded(child: CustomTextField(label: "First Name", hintText: "Mohamed", controller: firstNameController)),
                            const SizedBox(width: 15),
                            Expanded(child: CustomTextField(label: "Last Name", hintText: "Adel", controller: lastNameController)),
                          ],
                        ),
                        CustomTextField(label: "Relationship", hintText: "Brother", controller: relationController),
                        const SizedBox(height: 10),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text("Phone Number", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500))
                        ),
                        const SizedBox(height: 8),
                        IntlPhoneField(
                          initialCountryCode: 'EG',
                          onChanged: (phone) => fullPhoneNumber = phone.completeNumber,
                          decoration: InputDecoration(
                            hintText: '1551471747',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                        ),
                        const SizedBox(height: 30),
                        CustomButton(text: "Save", onPressed: _saveContact),
                        const SizedBox(height: 12),
                        _buildImagePickerButton(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientTitle() {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(colors: AppColors.logoGradient).createShader(bounds),
      child: const Text("Add contact", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }

  Widget _buildImagePickerButton() {
    return SizedBox(
      width: double.infinity,
      height: _selectedImage == null ? 48 : 120,
      child: OutlinedButton(
        onPressed: _pickImage,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF4983F6)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: _selectedImage == null
          ? const Text("add picture", style: TextStyle(color: Colors.black))
          : ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_selectedImage!, fit: BoxFit.cover, width: double.infinity)),
      ),
    );
  }
}