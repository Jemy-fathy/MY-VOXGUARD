import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class IncomingFakeCallMom extends StatefulWidget {
  final String name;
  final String imagePath;
  final String callerName;
  final String callTime;
  final String ringtone;

  const IncomingFakeCallMom({
    super.key,
    required this.name,
    required this.imagePath,
    required this.callerName,
    required this.callTime,
    required this.ringtone,
  });

  @override
  State<IncomingFakeCallMom> createState() => _IncomingFakeCallMomState();
}

class _IncomingFakeCallMomState extends State<IncomingFakeCallMom> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _playRingtone();
  }

  Future<void> _playRingtone() async {
    String fileName = 'default_ringtone.mp3';
    switch (widget.ringtone) {
      case 'Default Ringtone':
        fileName = 'default_ringtone.mp3';
        break;
      case 'Classic Bell':
        fileName = 'classic_bell.mp3';
        break;
      case 'Modern Alert':
        fileName = 'modern_alert.mp3';
        break;
      case 'Exciting Beat':
        fileName = 'exciting_beat.mp3';
        break;
      case 'iPhone Remix':
        fileName = 'iphone_remix.mp3';
        break;
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

  @override
  void dispose() {
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
                  color: const Color(0xFFE3EDFA),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'images/Mom.png',
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
            const Text(
              'Mom',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'mobile',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
                fontWeight: FontWeight.w400,
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildActionButton(
                    iconPath: 'images/alarm.png',
                    label: 'Remind me',
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  _buildActionButton(
                    iconPath: 'images/Message.png',
                    label: 'Message',
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCallButton(
                    imagePath: 'images/Group 47.png',
                    label: 'Decline',
                    onTap: () {
                      _audioPlayer.stop();
                      Navigator.pop(context);
                    },
                  ),
                  _buildCallButton(
                    imagePath: 'images/Group 46.png',
                    label: 'Answar',
                    onTap: () {
                      Navigator.pop(context);
                    },
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ImageIcon(
          AssetImage(iconPath),
          size: 28,
          color: Colors.black87,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
