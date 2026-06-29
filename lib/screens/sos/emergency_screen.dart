import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/colors.dart';
import '../../custom_widgets/custom_button.dart';
import 'home_screen.dart';
import 'safe_screen.dart';
import 'sos_service.dart';

/// The manual-SOS grace screen.
///
/// After the user presses the SOS button this screen runs a short countdown so
/// an accidental tap can be cancelled. When the countdown completes it opens an
/// SOS session on the server, launches the background guard (live location +
/// audio recording) and hands off to [SafeHomeScreen].
///
/// Flow:
/// ```
/// countdown ──(reaches 0)──▶ dispatching ──(success)──▶ SafeHomeScreen
///     │                          │
///   cancel                     failure
///     ▼                          ▼
///  HomeScreen                  error ──(retry)──▶ dispatching
///                                │
///                              cancel ─▶ HomeScreen
/// ```
class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

/// What the screen is currently doing.
enum _Phase { countdown, dispatching, error }

class _EmergencyScreenState extends State<EmergencyScreen> {
  /// Length of the cancel grace period, in seconds.
  static const int _countdownSeconds = 3;

  final SosService _sosService = const SosService();

  Timer? _countdownTimer;
  int _secondsRemaining = _countdownSeconds;
  _Phase _phase = _Phase.countdown;

  // Alert options the user can toggle while the countdown is still running.
  bool _shareLocation = true;
  bool _recordAudio = true;

  // Raised when the user aborts so an in-flight dispatch can clean up the
  // session it may have just created instead of leaving it open on the server.
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

  /// Opens the SOS session, starts the background guard, then routes to the
  /// active-alert screen. Surfaces an [_Phase.error] state on failure.
  Future<void> _dispatchSos() async {
    setState(() => _phase = _Phase.dispatching);

    final session = await _sosService.startSession(triggerType: 'manual');

    // The user aborted (or left the screen) while the request was in flight:
    // close the freshly-created session so nothing keeps running server-side.
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

  /// Aborts the alert and returns home. Safe to call in any phase.
  void _abort() {
    _countdownTimer?.cancel();
    _aborted = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  /// Retries dispatch after a failure (the grace period is not repeated).
  void _retry() => _dispatchSos();

  // --- UI ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
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
                label: 'Share live location',
                value: _shareLocation,
                onChanged: _canEditOptions
                    ? (value) => setState(() => _shareLocation = value)
                    : null,
              ),
              const SizedBox(height: 16),
              _ActionCard(
                icon: Icons.mic_rounded,
                label: 'Record audio',
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

  /// Options can only be changed while the countdown is still running.
  bool get _canEditOptions => _phase == _Phase.countdown;

  String get _title => switch (_phase) {
        _Phase.countdown => 'SOS Mode Activated',
        _Phase.dispatching => 'Sending SOS…',
        _Phase.error => "Couldn't send SOS",
      };

  String get _subtitle => switch (_phase) {
        _Phase.countdown => 'Sending alerts to your emergency contacts',
        _Phase.dispatching => 'Contacting your emergency contacts',
        _Phase.error => 'Check your connection and try again',
      };

  /// The large central status element: the countdown number, a spinner while
  /// dispatching, or an error glyph.
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
    if (_phase == _Phase.error) {
      return Column(
        children: [
          CustomButton(text: 'Try Again', onPressed: _retry),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _abort,
            child: const Text(
              'Back to Home',
              style: TextStyle(color: Colors.black54),
            ),
          ),
        ],
      );
    }

    // Countdown and dispatching share a single cancel action.
    return CustomButton(text: 'Cancel SOS', onPressed: _abort);
  }
}

/// A pill-shaped toggle row for an alert option (live location / audio).
/// A `null` [onChanged] renders the switch as disabled.
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 25),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primaryPurple, size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              label,
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
