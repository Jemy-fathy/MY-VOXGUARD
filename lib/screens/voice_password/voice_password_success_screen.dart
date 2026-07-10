import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:vox_guard/screens/sos/home_screen.dart';
import '../../config/colors.dart';
import '../../services/background_monitor_service.dart';
import '../../services/voice_monitor_service.dart';

class VoicePasswordSuccessScreen extends StatelessWidget {
  final String? phrase;
  const VoicePasswordSuccessScreen({super.key, this.phrase});

  @override
  Widget build(BuildContext context) {
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
            stops:  [0.0, 0.3, 0.7],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('images/logo.png', height: 32),
                  const SizedBox(width: 8),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        Color(0xFF4983F6),
                        Color(0xFFC175F5),
                        Color(0XFFFBACB7),
                      ],
                    ).createShader(bounds),
                    child: const Text(
                      'voxguard',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(flex: 2),
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFD546F3).withOpacity(0.2),
                ),
                child: const Center(
                  child: Icon(
                    Icons.mic,
                    color: Color(0xFFD546F3),
                    size: 64,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    Color(0xFF4983F6),
                    Color(0xFFC175F5),
                    Color(0XFFFBACB7),
                  ],
                ).createShader(bounds),
                child: Text(
                  'voice_added'.tr(),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(flex: 2),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 20,
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCB30E0),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF375DFB),
                          width: 1,
                        ),
                      ),
                      child: ElevatedButton(
                        onPressed: () async {
                          // ✅ Reload the new phrase into VoiceMonitorService
                          await VoiceMonitorService().loadSettingsOnly();

                          // ✅ Start background service so listening begins
                          // immediately — even if the app is later closed.
                          final bool isRunning =
                              await BackgroundMonitorService().isRunning;
                          if (!isRunning) {
                            await BackgroundMonitorService()
                                .startBackgroundMonitoring();
                            debugPrint(
                                '[VoiceSuccess] 🟢 Background monitor started after phrase registration.');
                          } else {
                            // Restart so the new phrase is picked up
                            await BackgroundMonitorService()
                                .stopBackgroundMonitoring();
                            await BackgroundMonitorService()
                                .startBackgroundMonitoring();
                            debugPrint(
                                '[VoiceSuccess] 🔄 Background monitor restarted with new phrase.');
                          }

                          // Capture context before async gap
                          if (!context.mounted) return;
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const HomeScreen()),
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'confirm'.tr(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF375DFB),
                          width: 1,
                        ),
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'add_another_one'.tr(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
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
    );
  }
}