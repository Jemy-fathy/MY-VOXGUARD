import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart'; // 🚨 استدعاء الباكيدج لطلب الصلاحيات برمجياً
import '../../config/colors.dart';
import '../../custom_widgets/custom_button.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    // 🚨 طلب الصلاحيات بمجرد فتح الشاشة الأولى فوراً
    _requestAppPermissions();
  }

  Future<void> _requestAppPermissions() async {
  // 1. أولاً نطلب الأذونات الأساسية (الموقع أثناء الاستخدام، المايك، الإشعارات)
  Map<Permission, PermissionStatus> statuses = await [
    Permission.location,
    Permission.microphone,
    Permission.notification,
  ].request();

  // 2. بعد أن يوافق المستخدم على "أثناء الاستخدام"، نطلب "السماح دائماً" (Always Allow)
  if (await Permission.location.isGranted) {
    // نتحقق إذا كان يحتاج إذن الخلفية
    if (await Permission.locationAlways.request().isGranted) {
      debugPrint("تم الحصول على صلاحية الموقع دائماً بنجاح");
    } else {
      // إذا رفض، نفتح الإعدادات ليقوم المستخدم بتفعيلها يدوياً (مهم جداً!)
      openAppSettings();
    }
  }
}

  @override
  Widget build(BuildContext context) {
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
              child: const Text(
                "voxguard",
                style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white),
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
                child: const Text(
                  "YOUR VOICE IS\nYOUR SHIELD",
                  textAlign: TextAlign.center,
                  style: TextStyle(
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
                text: "start",
                onPressed: () => Navigator.pushNamed(context, '/login'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}