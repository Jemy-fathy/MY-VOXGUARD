import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:vox_guard/screens/emergency_screen.dart';
import '../../config/colors.dart';
import '../../config/api_config.dart';
import '../../services/background_monitor_service.dart';
import '../../services/voice_monitor_service.dart';
import 'voice_password_success_screen.dart';

class VoicePasswordSetupScreen extends StatefulWidget {
  const VoicePasswordSetupScreen({super.key});

  @override
  State<VoicePasswordSetupScreen> createState() =>
      _VoicePasswordSetupScreenState();
}

class _VoicePasswordSetupScreenState extends State<VoicePasswordSetupScreen> {
  double _sensitivity = 55.0;
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  int _recordCount = 0;
  final List<String> _recordedFiles = [];
  bool _isUploading = false;
  bool _isTesting = false;
  bool _isUploaded = false;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechEnabled = false;
  String _recognizedText = "";
  final TextEditingController _phraseController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
    _initSpeech();
    _phraseController.addListener(() {
      setState(() {});
    });
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? 'default';
    setState(() {
      _sensitivity = prefs.getDouble('voice_sensitivity_$userId') ?? 55.0;
      _phraseController.text = prefs.getString('voice_phrase_$userId') ?? "";
    });
  }

  Future<void> _saveSensitivity(double value) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? 'default';
    await prefs.setDouble('voice_sensitivity_$userId', value);
  }

  void _initSpeech() async {
    _speechEnabled = await _speech.initialize();
    setState(() {});
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _phraseController.dispose();
    super.dispose();
  }

  String _localizeDigits(String input) {
    if (context.locale.languageCode != 'ar') return input;
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < english.length; i++) {
      input = input.replaceAll(english[i], arabic[i]);
    }
    return input;
  }

  Future<void> _handleRecording() async {
    if (_phraseController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('enter_phrase_error'.tr())),
      );
      return;
    }

    if (_isRecording) {
      final path = await _audioRecorder.stop();
      if (_speechEnabled) {
        await _speech.stop();
      }
      setState(() {
        _isRecording = false;
        if (path != null) {
          _recordedFiles.add(path);
          _recordCount++;
        }
      });
      if (_recordCount == 3) {
        _uploadVoices();
      }
    } else {
      if (await _audioRecorder.hasPermission()) {
        final Directory tempDir = await getTemporaryDirectory();
        final String path = '${tempDir.path}/voice_#${_recordCount + 1}.wav';
        
        const config = RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        );


        await _audioRecorder.start(config, path: path);
        setState(() {
          _isRecording = true;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('mic_permission_denied'.tr())),
        );
      }
    }
  }

  Future<void> _uploadVoices() async {
    if (_phraseController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('enter_phrase_error'.tr())),
      );
      setState(() {
        _recordCount = 0;
        _recordedFiles.clear();
      });
      return;
    }

    setState(() => _isUploading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? 'unknown_user';
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: You are not logged in. Please log in again.')),
        );
        setState(() => _isUploading = false);
        return;
      }

      // ── Step 1: Enroll voice samples in AI server ──
      final aiDio = Dio();
      aiDio.options.connectTimeout = const Duration(seconds: 30);
      aiDio.options.receiveTimeout = const Duration(seconds: 30);

      final aiFormData = FormData.fromMap({
        "user_id": userId,
        "user_name": userId,
        "audio_1": await MultipartFile.fromFile(_recordedFiles[0], filename: "audio_1.wav"),
        "audio_2": await MultipartFile.fromFile(_recordedFiles[1], filename: "audio_2.wav"),
        "audio_3": await MultipartFile.fromFile(_recordedFiles[2], filename: "audio_3.wav"),
      });

      final aiResponse = await aiDio.post(ApiConfig.enroll, data: aiFormData);

      if (aiResponse.statusCode != 200) {
        throw Exception('AI server error: ${aiResponse.statusCode}');
      }

      // ── Step 2: Save phrase & sensitivity to Laravel ──
      final laravelDio = Dio();
      laravelDio.options.headers["Authorization"] = "Bearer $token";
      laravelDio.options.headers["Accept"] = "application/json";
      laravelDio.options.connectTimeout = const Duration(seconds: 15);
      laravelDio.options.receiveTimeout = const Duration(seconds: 15);

      try {
        await laravelDio.post(
          ApiConfig.setupVoicePassword,
          data: FormData.fromMap({
            "user_id": userId,
            "phrase": _phraseController.text.trim(),
            "sensitivity": _sensitivity.toInt(),
            "timer_duration": 30,
          }),
        );
      } catch (_) {
        // Laravel save is secondary — don't fail the whole flow if it errors
      }

      // ── Step 3: Save settings locally ──
      await prefs.setString('voice_phrase', _phraseController.text.trim());
      await prefs.setString('voice_phrase_$userId', _phraseController.text.trim());
      await prefs.setDouble('voice_sensitivity', _sensitivity / 100);
      await prefs.setDouble('voice_sensitivity_$userId', _sensitivity);

      if (!mounted) return;

      setState(() {
        _isUploaded = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice password registered! You can now test it below before locking your phone.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      String errorMsg = e.toString();
      if (e is DioException && e.response != null) {
        final data = e.response?.data;
        if (data is Map) {
          errorMsg = data['detail']?.toString() ?? data['message']?.toString() ?? data.toString();
        } else {
          errorMsg = data.toString();
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('upload_failed'.tr(args: [errorMsg])),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _recordCount = 0;
        _recordedFiles.clear();
      });
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _resetRecordings() {
    setState(() {
      _recordCount = 0;
      _recordedFiles.clear();
      _isRecording = false;
      _recognizedText = "";
      _isUploaded = false;
    });
  }

  Future<void> _finishSetup() async {
    setState(() => _isUploading = true);
    try {
      // ── Step 4: Auto-start background monitoring ──
      await VoiceMonitorService().loadSettingsOnly();
      await BackgroundMonitorService().startBackgroundMonitoring();
      debugPrint('[VoiceSetup] ✅ Background monitoring started');

      // ── Step 5: Navigate to success screen ──
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VoicePasswordSuccessScreen(
            phrase: _phraseController.text.trim(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start background service: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _testVoiceMatch() async {
    if (_isTesting) return; // Prevent double calls

    if (await _audioRecorder.hasPermission()) {
      setState(() => _isTesting = true);
      try {
        final Directory tempDir = await getTemporaryDirectory();
        final String path = '${tempDir.path}/test_voice.wav';
        
        const config = RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        );

        await _audioRecorder.start(config, path: path);
        
        // Record for exactly 4 seconds (Auto-stop)
        await Future.delayed(const Duration(seconds: 4));
        
        final testPath = await _audioRecorder.stop();
        if (testPath != null) {
          await _verifyAndTriggerSOS(testPath, isTesting: true);
        }
      } catch (e) {
        print("Test Error: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Test failed: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isTesting = false);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('mic_permission_denied'.tr())),
      );
    }
  }

  Future<void> _verifyAndTriggerSOS(String audioPath, {bool isTesting = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final userId = prefs.getString('user_id') ?? 'unknown_user';
      final dio = Dio();
      // Set timeout
      dio.options.connectTimeout = const Duration(seconds: 10);
      dio.options.receiveTimeout = const Duration(seconds: 10);

      if (token != null) {
        dio.options.headers["Authorization"] = "Bearer $token";
      }
      dio.options.headers["Accept"] = "application/json";

      // AI /verify_user_id expects: user_id (Form) + audio (File)
      FormData formData = FormData.fromMap({
        "user_id": userId,
        "audio": await MultipartFile.fromFile(audioPath, filename: "verify.wav"),
      });

      final response = await dio.post(
        ApiConfig.verifyVoice,
        data: formData,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        bool isMatch = data['match'] ?? false;
        double score = (data['score'] ?? 0.0) * 100;
        
        if (isMatch || (data['score'] ?? 0.0) >= (_sensitivity / 100)) {
          if (!mounted) return;
          
          if (isTesting) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Voice matched! Score: ${score.toStringAsFixed(1)}% - Triggering SOS...'),
                backgroundColor: Colors.green,
              ),
            );
          }

          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const EmergencyScreen()),
          );
        } else if (isTesting) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Voice mismatch! Score: ${score.toStringAsFixed(1)}%'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Verify Error: $e');
      if (mounted && isTesting) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network or Server Error: $e')),
        );
      }
    }
  }

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
            colors: [ AppColors.bgBlueLight, AppColors.bgPurpleLight, Colors.white,],
            stops:  [0.0, 0.3, 0.7],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: context.locale.languageCode == 'ar' ? Alignment.centerRight : Alignment.centerLeft,
                          child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.black,
                            size: 24,
                          ),
                        ),
                      ),
                       Row(
                        mainAxisSize: MainAxisSize.min,
                        children: context.locale.languageCode == 'ar' 
                          ? [
                              ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [Color(0xFF4983F6), Color(0xFFC175F5), Color(0XFFFBACB7)],
                                ).createShader(bounds),
                                child: Text(
                                  'app_name'.tr(),
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Image.asset('images/logo.png', height: 32),
                            ]
                          : [
                              Image.asset('images/logo.png', height: 32),
                              const SizedBox(width: 8),
                              ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [Color(0xFF4983F6), Color(0xFFC175F5), Color(0XFFFBACB7)],
                                ).createShader(bounds),
                                child: const Text(
                                  'voxguard',
                                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF4983F6), Color(0xFFC175F5), Color(0XFFFBACB7)],
                  ).createShader(bounds),
                  child: Text(
                    'voice_password_title'.tr(),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'record_phrase_3_times'.tr(),
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),

                const SizedBox(height: 40),
                GestureDetector(
                  onTap: (_isUploading || _phraseController.text.isEmpty || _recordCount >= 3) ? null : _handleRecording,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (_recordCount >= 3 ? Colors.green : (_isRecording ? Colors.red : const Color(0xFFD546F3))).withOpacity(0.1),
                        ),
                      ),
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (_recordCount >= 3 ? Colors.green : (_isRecording ? Colors.red : const Color(0xFFD546F3))).withOpacity(0.2),
                          boxShadow: [
                            BoxShadow(
                              color: (_recordCount >= 3 ? Colors.green : (_isRecording ? Colors.red : const Color(0xFFD546F3))).withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Icon(
                          _recordCount >= 3 ? Icons.check_circle : (_isRecording ? Icons.stop : Icons.mic),
                          color: _recordCount >= 3 ? Colors.green : (_isRecording ? Colors.red : const Color(0xFFD546F3)),
                          size: 48,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isUploading 
                    ? 'uploading_samples'.tr() 
                    : (_recordCount >= 3 
                        ? 'all_samples_recorded'.tr()
                        : (_isRecording 
                            ? 'recording_sample'.tr(args: [_localizeDigits((_recordCount + 1).toString())]) 
                            : 'tap_to_record'.tr(args: [_localizeDigits((_recordCount + 1).toString())]))),
                  style: TextStyle(color: Colors.grey[600], fontSize: 16, fontWeight: FontWeight.w500),
                ),
                if (_recordCount > 0 && !_isRecording && !_isUploading)
                  TextButton.icon(
                    onPressed: _resetRecordings,
                    icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.primaryPurple),
                    label: Text(
                      're_record'.tr(),
                      style: const TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.bold),
                    ),
                  ),
                if (_isRecording && _recognizedText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, left: 24, right: 24),
                    child: Text(
                      '“$_recognizedText”',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.primaryPurple,
                        fontSize: 18,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'your_safe_phrase'.tr(),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.black, width: 1.2),
                        ),
                        child: TextField(
                          controller: _phraseController,
                          textAlign: TextAlign.start,
                          style: const TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'safe_phrase_hint'.tr(),
                            hintStyle: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'adjust_sensitivity'.tr(),
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFCA52DA)),
                            ),
                            Text(
                              '${_localizeDigits(_sensitivity.toInt().toString())}%',
                              style: const TextStyle(fontSize: 16, color: Color(0xFFBA68C8), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: const Color(0xFFD546F3),
                            inactiveTrackColor: Colors.grey[300],
                            thumbColor: const Color(0xFFD546F3),
                            overlayColor: const Color(0xFFD546F3).withOpacity(0.2),
                            trackHeight: 8,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                          ),
                          child: Slider(
                            value: _sensitivity,
                            min: 0,
                            max: 100,
                            onChanged: (value) {
                              setState(() {
                                _sensitivity = value;
                              });
                              _saveSensitivity(value);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      if (_isUploading)
                        const CircularProgressIndicator(color: Color(0xFFCB30E0))
                      else ...[
                        if (!_isUploaded) ...[
                          // Confirm & Upload button (Only active when 3 recordings are ready)
                          Container(
                            width: double.infinity,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFCB30E0),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF375DFB), width: 1),
                            ),
                            child: ElevatedButton(
                              onPressed: _recordCount == 3 ? _uploadVoices : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: Text(
                                'confirm'.tr(),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF375DFB), width: 1),
                            ),
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                              child: Text(
                                'skip_for_now'.tr(),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
                              ),
                            ),
                          ),
                        ] else ...[
                          // Test Voice Match Button
                          Container(
                            width: double.infinity,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFD546F3), width: 1.5),
                            ),
                            child: ElevatedButton.icon(
                              onPressed: _isTesting ? null : _testVoiceMatch,
                              icon: _isTesting 
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD546F3)))
                                : const Icon(Icons.verified_user_rounded, color: Color(0xFFD546F3)),
                              label: Text(
                                _isTesting ? 'Testing...' : 'test_voice_match'.tr(),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFD546F3)),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Activate & Finish Button
                          Container(
                            width: double.infinity,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFCB30E0),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF375DFB), width: 1),
                            ),
                            child: ElevatedButton(
                              onPressed: _finishSetup,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text(
                                'Activate & Finish',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

