import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:vox_guard/screens/fake_call/incoming_fake_call_dad.dart';
import 'package:vox_guard/screens/fake_call/incoming_fake_call_mom.dart';
import 'package:vox_guard/screens/fake_call/incoming_fake_call_police.dart';
import 'fake_call_success_screen.dart';

class FakeCallScreen extends StatefulWidget {
  const FakeCallScreen({super.key});

  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen> {
  String selectedCaller = 'Mom';
  String selectedTime = 'Now';
  String selectedRingtone = 'Default Ringtone';
  final AudioPlayer _audioPlayer = AudioPlayer();

  final List<String> ringtones = [
    'Default Ringtone',
    'Classic Bell',
    'Modern Alert',
    'Exciting Beat',
    'iPhone Remix',
    'Soft Melody',
  ];

  final List<String> timeOptions = [
    'Now',
    '30sec',
    '1min',
    '5min',
    '10min',
    '30min',
    '1hour',
    '1.5hour',
    '2hour',
    '3hour',
  ];

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _previewRingtone(String ringtoneName) async {
    String fileName = 'default_ringtone.mp3';
    switch (ringtoneName) {
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
      AudioCache.instance.prefix = '';
      await _audioPlayer.stop();
      await _audioPlayer.setSource(AssetSource('assets/audio/$fileName'));
      await _audioPlayer.resume();
    } catch (e) {
      debugPrint('Error previewing ringtone: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            height: 180,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFFB196F9), Color(0xFFCB30E0)],
              ),
            ),
            padding: const EdgeInsets.only(top: 40, left: 10),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text(
                  'Fake call',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              transform: Matrix4.translationValues(0, -25, 0),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGradientTitle("Who's Calling ?"),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildCallerItem('Mom', 'images/Woman.png'),
                        _buildCallerItem('Dad', 'images/Man.png'),
                        _buildCallerItem('Police', 'images/Police.png'),
                      ],
                    ),
                    const SizedBox(height: 35),
                    _buildGradientTitle("When to call ?"),
                    const SizedBox(height: 16),
                    Column(
                      children: [
                        Row(
                          children: timeOptions
                              .sublist(0, 5)
                              .map((time) => Expanded(child: _timeChip(time)))
                              .toList(),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: timeOptions
                              .sublist(5, 10)
                              .map((time) => Expanded(child: _timeChip(time)))
                              .toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 35),
                    _buildGradientTitle("Ringtone"),
                    const SizedBox(height: 12),
                    _buildRingtoneDropdown(),
                    const SizedBox(height: 50),
                    _buildScheduleButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallerItem(String name, String imagePath) {
    bool isSelected = selectedCaller == name;
    return GestureDetector(
      onTap: () {
        setState(() => selectedCaller = name);
      },
      child: Container(
        width: MediaQuery.of(context).size.width * 0.28,
        height: 116,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFCB30E0).withOpacity(0.05)
              : const Color(0XFFF3F3F3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFCB30E0) : Colors.grey.shade300,
            width: isSelected ? 2.0 : 0.8,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? const Color(0xFFCB30E0).withOpacity(0.1)
                    : const Color(0xFFF3E5F5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.asset(imagePath, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isSelected ? const Color(0xFFCB30E0) : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeChip(String text) {
    bool isSelected = selectedTime == text;
    return GestureDetector(
      onTap: () => setState(() => selectedTime = text),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFCB30E0).withOpacity(0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFCB30E0) : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? const Color(0xFFCB30E0) : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildRingtoneDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.music_note, color: Color(0xFFCB30E0)),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedRingtone,
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.black54,
                ),
                items: ringtones
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) {
                  setState(() => selectedRingtone = v!);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientTitle(String text) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0XFF4983F6), Color(0xFFC175F5), Color(0XFFFBACB7)],
      ).createShader(bounds),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildScheduleButton() {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        color: const Color(0xFFCB30E0),
        borderRadius: BorderRadius.circular(18),
      ),
      child: ElevatedButton(
        onPressed: () {
          String imgPath = 'images/Woman.png';
          if (selectedCaller == 'Dad') imgPath = 'images/Man.png';
          if (selectedCaller == 'Police') imgPath = 'images/Police.png';

          if (selectedTime == 'Now') {
            Widget target;
            if (selectedCaller == 'Mom') {
              target = IncomingFakeCallMom(
                name: selectedCaller,
                imagePath: imgPath,
                callerName: selectedCaller,
                callTime: selectedTime,
                ringtone: selectedRingtone,
              );
            } else if (selectedCaller == 'Dad') {
              target = IncomingFakeCallDad(
                name: selectedCaller,
                imagePath: imgPath,
                callerName: selectedCaller,
                callTime: selectedTime,
                ringtone: selectedRingtone,
              );
            } else {
              target = IncomingFakeCallPolice(
                name: selectedCaller,
                imagePath: imgPath,
                callerName: selectedCaller,
                callTime: selectedTime,
                ringtone: selectedRingtone,
              );
            }
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => target),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FakeCallSuccessScreen(
                  callTime: selectedTime,
                  name: selectedCaller,
                  imagePath: imgPath,
                  callerName: selectedCaller,
                  ringtone: selectedRingtone,
                ),
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
        ),
        child: const Text(
          'schedule call',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
