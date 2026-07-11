import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  String selectedCaller = 'mom';
  String selectedTime = 'now';
  String selectedRingtone = 'ringtone_default';

  final List<String> ringtones = [
    'ringtone_default',
    'ringtone_classic',
    'ringtone_modern',
    'ringtone_exciting',
    'ringtone_iphone',
    'ringtone_soft',
  ];
  final List<String> timeOptions = [
    'now',
    'sec_30',
    'min_1',
    'min_5',
    'min_10',
    'min_30',
    'hour_1',
    'hour_1_5',
    'hour_2',
    'hour_3',
  ];

  @override
  void dispose() {
    super.dispose();
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
            padding: const EdgeInsets.only(top: 40, left: 10, right: 10),
            child: Row(
              textDirection: context.locale.languageCode == 'ar'
                  ? ui.TextDirection.rtl
                  : ui.TextDirection.ltr,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                Text(
                  'fake_call_title'.tr(),
                  style: const TextStyle(
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
                    _buildGradientTitle('whos_calling'.tr()),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildCallerItem('mom', 'images/Woman.png'),
                        _buildCallerItem('dad', 'images/Man.png'),
                        _buildCallerItem('police', 'images/Police.png'),
                      ],
                    ),
                    const SizedBox(height: 35),
                    _buildGradientTitle('when_to_call'.tr()),
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
                    _buildGradientTitle('ringtone'.tr()),
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

  Widget _buildCallerItem(String key, String imagePath) {
    bool isSelected = selectedCaller == key;
    return GestureDetector(
      onTap: () {
        setState(() => selectedCaller = key);
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
              key.tr(),
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

  Widget _timeChip(String key) {
    bool isSelected = selectedTime == key;
    return GestureDetector(
      onTap: () => setState(() => selectedTime = key),
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
          key.tr(),
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
                    .map((r) => DropdownMenuItem(value: r, child: Text(r.tr())))
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
        onPressed: () async {
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('activity_log_fake_call_time', DateTime.now().toIso8601String());
          } catch (e) {
            debugPrint("Error saving fake call timestamp: $e");
          }

          String imgPath = 'images/Woman.png';
          if (selectedCaller == 'dad') imgPath = 'images/Man.png';
          if (selectedCaller == 'police') imgPath = 'images/Police.png';

          if (selectedTime == 'now') {
            Widget target;
            if (selectedCaller == 'mom') {
              target = IncomingFakeCallMom(
                name: 'mom'.tr(),
                imagePath: imgPath,
                callerName: 'mom'.tr(),
                callTime: 'now'.tr(),
                ringtone: selectedRingtone.tr(),
              );
            } else if (selectedCaller == 'dad') {
              target = IncomingFakeCallDad(
                name: 'dad'.tr(),
                imagePath: imgPath,
                callerName: 'dad'.tr(),
                callTime: 'now'.tr(),
                ringtone: selectedRingtone.tr(),
              );
            } else {
              target = IncomingFakeCallPolice(
                name: 'police'.tr(),
                imagePath: imgPath,
                callerName: 'police'.tr(),
                callTime: 'now'.tr(),
                ringtone: selectedRingtone.tr(),
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
                  callTime: selectedTime.tr(),
                  name: selectedCaller,
                  imagePath: imgPath,
                  callerName: selectedCaller.tr(),
                  ringtone: selectedRingtone.tr(),
                ),
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
        ),
        child: Text(
          'schedule_call'.tr(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
