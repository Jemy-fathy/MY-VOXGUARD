import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:ui' as ui;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../services/wearable_service.dart';
import '../../services/bluetooth_service.dart';
import '../../config/api_config.dart';
import '../emergency_screen.dart';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  int _heartRate = 85;
  int _batteryLevel = 78;
  int _steps = 3240;
  final String _bloodPressure = "120/80";
  String _motionStatus = 'still';
  bool _isSyncing = false;
  Timer? _updateTimer;
  final Random _random = Random();
  StreamSubscription<int>? _hrSubscription;
  bool _hasConnectedDevice = false;

  // Voice SOS Variables
  final AudioRecorder _audioRecorder = AudioRecorder();
  final SpeechToText _speech = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  bool _isVerifyingVoice = false;
  String _safePhrase = ""; // Will be loaded from prefs


  @override
  void initState() {
    super.initState();
    _loadSafePhrase();
    _initSpeech();
    
    final bleService = AppBluetoothService();
    if (bleService.connectedDevice != null && bleService.hasHeartRateService) {
      _hasConnectedDevice = true;
      _hrSubscription = bleService.heartRateStream.listen((hr) {
        if (mounted) {
          setState(() {
            _heartRate = hr;
          });
          _sendHealthUpdate();
        }
      });
    }
    
    _startMonitoring();
  }

  Future<void> _loadSafePhrase() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _safePhrase = prefs.getString('voice_phrase') ?? "";
    });
  }

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onError: (error) => print('Speech Error: $error'),
        onStatus: (status) => print('Speech Status: $status'),
      );
      if (_speechEnabled) {
        _startListening();
      }
      setState(() {});
    } catch (e) {
      print('Speech Init Exception: $e');
    }
  }

  void _startListening() {
    if (!_speechEnabled || _isListening) return;
    
    _speech.listen(
      onResult: (result) {
        String recognized = result.recognizedWords.toLowerCase();
        print('Recognized: $recognized');
        if (_safePhrase.isNotEmpty && recognized.contains(_safePhrase.toLowerCase())) {
          _onPhraseDetected();
        }
      },
      localeId: context.locale.languageCode == 'ar' ? 'ar_SA' : 'en_US',
      listenFor: const Duration(minutes: 5), // Keep listening
      pauseFor: const Duration(seconds: 10),
      cancelOnError: false,
      partialResults: true,
      listenMode: ListenMode.confirmation,
    );
    setState(() => _isListening = true);
  }

  Future<void> _onPhraseDetected() async {
    // 1. Stop speech to free mic
    await _speech.stop();
    setState(() {
      _isListening = false;
      _isVerifyingVoice = true;
    });

    // 2. Record 3 seconds for biometric verify
    if (await _audioRecorder.hasPermission()) {
      final Directory tempDir = await getTemporaryDirectory();
      final String path = '${tempDir.path}/sos_verify.wav';
      
      const config = RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      );

      await _audioRecorder.start(config, path: path);
      await Future.delayed(const Duration(seconds: 3));
      final recordPath = await _audioRecorder.stop();

      if (recordPath != null) {
        await _verifyAndTriggerSOS(recordPath);
      }
    }

    // Resume listening if SOS not triggered
    if (mounted && _isVerifyingVoice) {
      setState(() => _isVerifyingVoice = false);
      _startListening();
    }
  }

  Future<void> _verifyAndTriggerSOS(String audioPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final dio = Dio();
      if (token != null) {
        dio.options.headers["Authorization"] = "Bearer $token";
      }
      dio.options.headers["Accept"] = "application/json";

      final userId = prefs.getString('user_id') ?? 'unknown_user';
      final threshold = prefs.getDouble('voice_sensitivity') ?? 0.55;

      FormData formData = FormData.fromMap({
        "user_id": userId,
        "audio": await MultipartFile.fromFile(audioPath, filename: "sos_trigger.wav"),
        "threshold": threshold,
      });

      final response = await dio.post(
        ApiConfig.verifyVoice,
        data: formData,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        bool isMatch = data['match'] ?? false;
        double score = (data['score'] ?? 0.0);
        
        final prefs = await SharedPreferences.getInstance();
        double threshold = prefs.getDouble('voice_sensitivity') ?? 0.55;
        
        // Threshold check (Using dynamic threshold from settings)
        if (isMatch || score > threshold) {
          if (!mounted) return;
          // TRIGGER SOS
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const EmergencyScreen()),
          );
        } else {
          print("Voice mismatch for SOS trigger. Score: $score");
        }
      }
    } catch (e) {
      print('SOS Voice Verify Error: $e');
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _hrSubscription?.cancel();
    super.dispose();
  }

  void _startMonitoring() {
    _updateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _simulateData();
    });
  }

  Future<void> _sendHealthUpdate() async {
    if (_heartRate > 120) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('activity_log_wearable_time', DateTime.now().toIso8601String());
      } catch (e) {
        debugPrint("Error saving wearable warning time: $e");
      }
    }

    final healthData = {
      'heart_rate': _heartRate,
      'steps': _steps,
      'blood_pressure': _bloodPressure,
      'motion_status': _motionStatus,
      'battery_level': _batteryLevel,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await WearableService.updateHealth(healthData);
  }

  void _simulateData() async {
    if (!mounted) return;

    setState(() {
      if (!_hasConnectedDevice) {
        _heartRate = 60 + _random.nextInt(80); // Generates 60 to 139 bpm, allowing it to cross 120
      }
      _steps += _random.nextInt(10);
      _motionStatus = _random.nextDouble() > 0.8 ? 'moving' : 'still';
      if (_batteryLevel > 5) _batteryLevel -= (_random.nextInt(2) == 0 ? 1 : 0);
      _isSyncing = true;
    });

    await _sendHealthUpdate();

    if (mounted) {
      setState(() {
        _isSyncing = false;
      });
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            height: MediaQuery.of(context).size.height * 0.35,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFB323D1),
                  Color(0xFFE843EE),
                ],
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    textDirection: context.locale.languageCode == 'ar' ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Text(
                        'monitoring_title'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      // Live Indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.greenAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'live'.tr(),
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Voice Status Indicator
                if (_isVerifyingVoice)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    color: Colors.redAccent,
                    child: const Center(
                      child: Text(
                        "Verifying Voice Identity...",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(top: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(35),
                        topRight: Radius.circular(35),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(top: 30, bottom: 40),
                      child: Column(
                        children: [
                          // Wave Chart Card
                          _buildChartCard(),
                          const SizedBox(height: 24),
                          
                          // Grid of Health Metrics
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.1,
                            children: [
                              _buildMetricCard(
                                'steps'.tr(),
                                _localizeDigits('$_steps'),
                                Icons.directions_walk,
                                const Color(0xFF4983F6),
                              ),
                              _buildMetricCard(
                                'blood_pressure'.tr(),
                                _localizeDigits(_bloodPressure),
                                Icons.favorite_border,
                                const Color(0xFFE843EE),
                              ),
                              _buildMetricCard(
                                'motion_detection'.tr(),
                                _motionStatus.tr(),
                                Icons.person_outline,
                                const Color(0xFFCB30E0),
                              ),
                              _buildMetricCard(
                                'auto_sos_alert'.tr(),
                                'armed'.tr(),
                                Icons.sos,
                                const Color(0xFFCB30E0),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          
                          // Watch Battery Section
                          _buildBatteryCard(),
                          
                          const SizedBox(height: 40),
                          Text(
                            'monitoring_info'.tr(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF9E9E9E),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Action Button
                          _buildActionButton(context),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Color(0XFF4983F6),
                      Color(0xFFC175F5),
                      Color(0XFFFBACB7),
                    ],
                  ).createShader(bounds),
                  child: Text(
                    'live_heart_rate'.tr(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                 Row(
                   children: [
                     Text(
                       '${_localizeDigits('$_heartRate')} ${'bpm'.tr()}',
                       style: const TextStyle(
                         fontSize: 32,
                         fontWeight: FontWeight.bold,
                         color: Color(0xFFB323D1),
                       ),
                     ),
                     const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _hasConnectedDevice
                              ? Colors.green.shade100
                              : (AppBluetoothService().connectedDevice != null
                                  ? Colors.blue.shade100
                                  : Colors.orange.shade100),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _hasConnectedDevice
                              ? 'Bluetooth Live'
                              : (AppBluetoothService().connectedDevice != null
                                  ? '${AppBluetoothService().connectedDevice!.platformName} (Simulated)'
                                  : 'Simulated'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _hasConnectedDevice
                                ? Colors.green.shade800
                                : (AppBluetoothService().connectedDevice != null
                                    ? Colors.blue.shade800
                                    : Colors.orange.shade800),
                          ),
                        ),
                      ),
                   ],
                 ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'last_60_seconds'.tr(),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+${_localizeDigits('2')}%',
                      style: const TextStyle(fontSize: 12, color: Color(0xFFB323D1), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
            child: Image.asset(
              'images/live heart.png',
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, Colors.pink[50]!],
                  ),
                ),
                child: Center(
                  child: Icon(Icons.show_chart, size: 60, color: const Color(0xFFE843EE).withOpacity(0.2)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color == const Color(0xFF4983F6) ? color : Colors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBatteryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.battery_charging_full, color: Color(0xFF4CAF50), size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'watch_battery'.tr(),
                  style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_localizeDigits('$_batteryLevel')}%',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // Progress Bar
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _batteryLevel / 100,
                backgroundColor: Colors.grey[200],
                color: const Color(0xFF4CAF50),
                minHeight: 8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    bool isActive = _updateTimer?.isActive ?? false;
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFE843EE) : Colors.grey[300],
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (isActive)
            BoxShadow(
              color: const Color(0xFFE843EE).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isActive) {
              _updateTimer?.cancel();
            } else {
              _startMonitoring();
            }
            setState(() {});
          },
          borderRadius: BorderRadius.circular(20),
          child: Center(
            child: Text(
              isActive ? 'disable_monitoring'.tr() : 'enable_monitoring'.tr(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}


