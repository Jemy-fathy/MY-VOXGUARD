import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:vox_guard/screens/sos/home_screen.dart';
import 'package:vox_guard/screens/sos/safe_screen.dart';
import 'package:vox_guard/screens/sos/sos_service.dart';
import 'dart:ui' as ui;
import '../../config/colors.dart';
import '../../custom_widgets/custom_button.dart';


class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

enum _Phase { countdown, dispatching, error }

class _EmergencyScreenState extends State<EmergencyScreen> {
  static const int _countdownSeconds = 3;

  final SosService _sosService = const SosService();

  Timer? _countdownTimer;
  int _secondsRemaining = _countdownSeconds;
  _Phase _phase = _Phase.countdown;

  bool _shareLocation = true;
  bool _recordAudio = true;
  bool _aborted = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 1) {
        timer.cancel();
        _dispatchSos();
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  Future<void> _dispatchSos() async {
    setState(() => _phase = _Phase.dispatching);

    final session = await _sosService.startSession(triggerType: 'manual');

    if (!mounted || _aborted) {
      if (session != null) {
        await _sosService.cancelSession(session);
      }
      return;
    }

    if (session == null) {
      setState(() => _phase = _Phase.error);
      return;
    }

    await _sosService.startBackgroundGuard(
      session: session,
      shareLocation: _shareLocation,
      recordAudio: _recordAudio,
    );

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SafeHomeScreen(
          sosId: session.sosId,
          token: session.token,
          isLocationSharing: _shareLocation,
          isAudioRecording: _recordAudio,
        ),
      ),
    );
  }

  void _abort() {
    _countdownTimer?.cancel();
    _aborted = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  void _retry() => _dispatchSos();

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    return Scaffold(
      body: Container(
        width: double.infinity,
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
          child: Column(
            children: [
              const Spacer(flex: 3),
              _indicator(),
              const SizedBox(height: 10),
              Text(
                _title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryPurple,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.black45),
              ),
              const Spacer(),
              _ActionCard(
                icon: Icons.location_on,
                label: 'share_live_location_label'.tr(),
                value: _shareLocation,
                onChanged: _canEditOptions
                    ? (value) => setState(() => _shareLocation = value)
                    : null,
              ),
              const SizedBox(height: 16),
              _ActionCard(
                icon: Icons.mic_rounded,
                label: 'recording_audio'.tr(),
                value: _recordAudio,
                onChanged: _canEditOptions
                    ? (value) => setState(() => _recordAudio = value)
                    : null,
              ),
              const Spacer(flex: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
                child: _actions(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _canEditOptions => _phase == _Phase.countdown;

  String get _title => switch (_phase) {
        _Phase.countdown => 'sos_mode_activated'.tr(),
        _Phase.dispatching => context.locale.languageCode == 'ar' ? 'جاري إرسال الاستغاثة...' : 'Sending SOS…',
        _Phase.error => context.locale.languageCode == 'ar' ? 'تعذر إرسال الاستغاثة' : "Couldn't send SOS",
      };

  String get _subtitle => switch (_phase) {
        _Phase.countdown => 'sending_alerts'.tr(),
        _Phase.dispatching => context.locale.languageCode == 'ar' ? 'جاري الاتصال بجهات اتصال الطوارئ' : 'Contacting your emergency contacts',
        _Phase.error => context.locale.languageCode == 'ar' ? 'تأكد من الاتصال بالإنترنت وأعد المحاولة' : 'Check your connection and try again',
      };

  Widget _indicator() {
    switch (_phase) {
      case _Phase.countdown:
        return Text(
          '$_secondsRemaining',
          style: const TextStyle(
            fontSize: 180,
            fontWeight: FontWeight.w900,
            color: AppColors.primaryPurple,
          ),
        );
      case _Phase.dispatching:
        return const SizedBox(
          height: 100,
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primaryPurple),
          ),
        );
      case _Phase.error:
        return const SizedBox(
          height: 100,
          child: Icon(
            Icons.error_outline_rounded,
            size: 90,
            color: AppColors.primaryPurple,
          ),
        );
    }
  }

  Widget _actions() {
    final isArabic = context.locale.languageCode == 'ar';
    if (_phase == _Phase.error) {
      return Column(
        children: [
          CustomButton(
            text: isArabic ? 'إعادة المحاولة' : 'Try Again', 
            onPressed: _retry
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _abort,
            child: Text(
              isArabic ? 'العودة للرئيسية' : 'Back to Home',
              style: const TextStyle(color: Colors.black54),
            ),
          ),
        ],
      );
    }

    return CustomButton(
      text: 'cancel_sos'.tr(), 
      onPressed: _abort
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 25),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Row(
        textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primaryPurple, size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              label,
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.primaryPurple,
          ),
        ],
      ),
    );
  }
}
