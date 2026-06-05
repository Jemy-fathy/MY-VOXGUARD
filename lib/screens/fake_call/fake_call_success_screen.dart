import 'dart:async';
import 'package:flutter/material.dart';
import '/screens/fake_call/incoming_fake_call_dad.dart';
import '/screens/fake_call/incoming_fake_call_mom.dart';
import '/screens/fake_call/incoming_fake_call_police.dart';

class FakeCallSuccessScreen extends StatefulWidget {
  final String callTime;
  final String name;
  final String imagePath;
  final String callerName;
  final String ringtone;

  const FakeCallSuccessScreen({
    super.key,
    required this.callTime,
    required this.name,
    required this.imagePath,
    required this.callerName,
    required this.ringtone,
  });

  @override
  State<FakeCallSuccessScreen> createState() => _FakeCallSuccessScreenState();
}

class _FakeCallSuccessScreenState extends State<FakeCallSuccessScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAutoNavigation();
  }

  void _startAutoNavigation() {
    int seconds = _parseTimeToSeconds(widget.callTime);

    _timer = Timer(Duration(seconds: seconds), () {
      if (mounted) {
        _navigateToCall();
      }
    });
  }

  void _navigateToCall() {
    Widget target;
    if (widget.name == 'Mom') {
      target = IncomingFakeCallMom(
          name: widget.name,
          imagePath: widget.imagePath,
          callerName: widget.callerName,
          callTime: widget.callTime,
          ringtone: widget.ringtone);
    } else if (widget.name == 'Dad') {
      target = IncomingFakeCallDad(
          name: widget.name,
          imagePath: widget.imagePath,
          callerName: widget.callerName,
          callTime: widget.callTime,
          ringtone: widget.ringtone);
    } else {
      target = IncomingFakeCallPolice(
          name: widget.name,
          imagePath: widget.imagePath,
          callerName: widget.callerName,
          callTime: widget.callTime,
          ringtone: widget.ringtone);
    }

    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => target));
  }

  int _parseTimeToSeconds(String time) {
    String t = time.toLowerCase();
    if (t == 'now') return 0;
    int val = int.tryParse(t.replaceAll(RegExp(r'[^0-9]'), '')) ?? 5;
    if (t.contains('min')) return val * 60;
    return val;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String displayTime = (widget.callTime.toLowerCase() == 'now')
        ? 'immediately'
        : '${widget.callTime} later';

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE3EDFA), Color(0xFFE0C3FC)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('images/logo.png',
                      height: 40,
                      errorBuilder: (c, e, s) =>
                          const Icon(Icons.shield, color: Colors.purple)),
                  const SizedBox(width: 8),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        Color(0XFF4983F6),
                        Color(0xFFC175F5),
                        Color(0XFFFBACB7)
                      ],
                    ).createShader(bounds),
                    child: const Text(
                      'voxguard',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Color(0xFF4983F6),
                            Color(0xFFC175F5),
                            Color(0XFFFBACB7)
                          ],
                        ).createShader(bounds),
                        child: Text(
                          'The fake call is\nscheduled for $displayTime.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.3),
                        ),
                      ),
                      const SizedBox(height: 40),
                      // زرار الـ OK بتاعك
                      Container(
                        width: double.infinity,
                        height: 55,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFFCB30E0), Color(0xFFB028C9)]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('OK',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
