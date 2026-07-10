import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import '../../config/api_config.dart';

class IncomingFakeCallDad extends StatefulWidget {
  final String name;
  final String imagePath;
  final String callerName;
  final String callTime;
  final String ringtone;

  const IncomingFakeCallDad({
    super.key,
    required this.name,
    required this.imagePath,
    required this.callerName,
    required this.callTime,
    required this.ringtone,
  });

  @override
  State<IncomingFakeCallDad> createState() => _IncomingFakeCallDadState();
}

class _IncomingFakeCallDadState extends State<IncomingFakeCallDad> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isCallActive = false;
  Timer? _callTimer;
  int _callDuration = 0;

  String get _formattedTime {
    final minutes = (_callDuration / 60).floor().toString().padLeft(2, '0');
    final seconds = (_callDuration % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void initState() {
    super.initState();
    _playRingtone();
  }

  Future<void> _playRingtone() async {
    String fileName = 'default_ringtone.mp3';
    switch (widget.ringtone) {
      case 'ringtone_default':
      case 'Default Ringtone':
        fileName = 'default_ringtone.mp3';
        break;
      case 'ringtone_classic':
      case 'Classic Bell':
        fileName = 'classic_bell.mp3';
        break;
      case 'ringtone_modern':
      case 'Modern Alert':
        fileName = 'modern_alert.mp3';
        break;
      case 'ringtone_exciting':
      case 'Exciting Beat':
        fileName = 'exciting_beat.mp3';
        break;
      case 'ringtone_iphone':
      case 'iPhone Remix':
        fileName = 'iphone_remix.mp3';
        break;
      case 'ringtone_soft':
      case 'Soft Melody':
        fileName = 'soft_melody.mp3';
        break;
    }

    try {
      debugPrint('Attempting to play ringtone: assets/audio/$fileName');
      AudioCache.instance.prefix = '';
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setSource(AssetSource('assets/audio/$fileName'));
      await _audioPlayer.resume();
      debugPrint('Playback started successfully');
    } catch (e) {
      debugPrint('Error playing ringtone (assets/audio/$fileName): $e');
    }
  }

  Future<void> _answerCall() async {
    await _audioPlayer.stop();
    setState(() {
      _isCallActive = true;
    });

    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _callDuration++;
      });
    });

    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      final dio = Dio();
      final tempDir = await getTemporaryDirectory();
      final String tempPath = "${tempDir.path}/${ApiConfig.dadVoice.split('/').last}";
      final File file = File(tempPath);
      if (!await file.exists()) {
        await dio.download(ApiConfig.dadVoice, tempPath);
      }
      await _audioPlayer.setSource(DeviceFileSource(tempPath));
      await _audioPlayer.resume();
    } catch (e) {
      debugPrint('Error playing dad voice from API, trying fallback: $e');
      try {
        await _audioPlayer.setSource(UrlSource(ApiConfig.dadVoice));
        await _audioPlayer.resume();
      } catch (e2) {
        debugPrint('Fallback Dad play failed: $e2');
      }
    }
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 80),
            Center(
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE3EDFA),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'images/Dad.png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.person,
                        size: 80,
                        color: Color(0xFF1E3C72),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'dad'.tr(),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isCallActive ? _formattedTime : 'mobile'.tr(),
              style: const TextStyle(
                fontSize: 18,
                color: Colors.grey,
                fontWeight: FontWeight.w400,
              ),
            ),
            const Spacer(),
            if (!_isCallActive)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildActionButton(
                      iconPath: 'images/alarm.png',
                      label: 'remind_me'.tr(),
                      onTap: _showRemindMeOptions,
                    ),
                    _buildActionButton(
                      iconPath: 'images/Message.png',
                      label: 'message'.tr(),
                      onTap: _showMessageOptions,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
              child: _isCallActive
                  ? Center(
                      child: _buildCallButton(
                        imagePath: 'images/Group 47.png',
                        label: '',
                        onTap: () {
                          _audioPlayer.stop();
                          Navigator.pop(context);
                        },
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildCallButton(
                          imagePath: 'images/Group 47.png',
                          label: 'decline'.tr(),
                          onTap: () {
                            _audioPlayer.stop();
                            Navigator.pop(context);
                          },
                        ),
                        _buildCallButton(
                          imagePath: 'images/Group 46.png',
                          label: 'answer'.tr(),
                          onTap: _answerCall,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String iconPath,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ImageIcon(AssetImage(iconPath), size: 28, color: Colors.black87),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showRemindMeOptions() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.only(left: 16, right: 16, bottom: 160),
          decoration: BoxDecoration(
            color: const Color(0xFFE5E3E0),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 16, bottom: 8, left: 24),
                child: Text(
                  'Remind Me Later',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              _buildPopupOption(
                icon: Icons.access_time,
                text: 'In 1 hour',
                onTap: () {
                  Navigator.pop(context); // Close sheet
                  Navigator.pop(context); // Close call screen
                },
              ),
              const Divider(height: 1, color: Colors.black12),
              _buildPopupOption(
                icon: Icons.near_me_outlined,
                text: 'When I leave',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  },
);
  }

  void _showMessageOptions() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.only(left: 16, right: 16, bottom: 160),
          decoration: BoxDecoration(
            color: const Color(0xFFE5E3E0),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 16, bottom: 8, left: 24),
                child: Text(
                  'Respond with:',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              _buildPopupOption(
                text: 'Custom...',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
              ),
              const Divider(height: 1, color: Colors.black12),
              _buildPopupOption(
                icon: Icons.access_time,
                text: 'Can I call you later?',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
              ),
              const Divider(height: 1, color: Colors.black12),
              _buildPopupOption(
                icon: Icons.directions_walk,
                text: 'I\'m on my way.',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
              ),
              const Divider(height: 1, color: Colors.black12),
              _buildPopupOption(
                text: 'Sorry, I can\'t talk right now.',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  },
);
  }

  Widget _buildPopupOption({IconData? icon, required String text, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: Colors.black87),
              const SizedBox(width: 16),
            ] else
              const SizedBox(width: 36),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 17,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallButton({
    required String imagePath,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Image.asset(
            imagePath,
            width: 80,
            height: 80,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 12),
        if (label.isNotEmpty)
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }
}
