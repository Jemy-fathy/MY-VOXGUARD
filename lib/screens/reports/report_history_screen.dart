import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/api_config.dart';

class ReportHistoryScreen extends StatefulWidget {
  const ReportHistoryScreen({super.key});

  @override
  State<ReportHistoryScreen> createState() => _ReportHistoryScreenState();
}

class _ReportHistoryScreenState extends State<ReportHistoryScreen> {
  List<dynamic> reports = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? prefs.getString('auth_token');

      if (token == null) {
        throw Exception("Authentication token missing.");
      }

      final response = await http.get(
        Uri.parse(ApiConfig.incidentHistory),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          reports = data['reports'] ?? data['data'] ?? [];
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        await prefs.remove('token');
        await prefs.remove('auth_token');
        await prefs.remove('user_id');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Session expired. Please log in again.')),
          );
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      } else {
        setState(() {
          _errorMessage = "failed_to_fetch_reports".tr();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "error_occurred".tr();
        _isLoading = false;
      });
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'reviewed': return const Color(0xFFEBC1F9);
      case 'pending': return const Color(0xFFF1E9AA);
      case 'closed': return const Color(0xFFCED3D7);
      case 'action_taken': return const Color(0xFFEBC1F9);
      default: return const Color(0xFFCED3D7);
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'reviewed': return const Color(0xFFCA32DF);
      case 'pending': return const Color(0xFF757A43);
      case 'closed': return const Color(0xFF333333);
      case 'action_taken': return const Color(0xFFCA32DF);
      default: return const Color(0xFF333333);
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
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Container(
            height: 160,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFF8E9EFE), Color(0xFFE040FB)],
              ),
            ),
          ),
          Column(
            children: [
              Container(
                height: 140,
                width: double.infinity,
                padding: const EdgeInsets.only(top: 60, left: 16, right: 16),
                child: Row(
                  textDirection: context.locale.languageCode == 'ar' ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, 
                        size: 24,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'report_history'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white, size: 24),
                      onPressed: _fetchReports,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(35),
                      topRight: Radius.circular(35),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(35),
                      topRight: Radius.circular(35),
                    ),
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(color: Color(0xFFD546F3)),
                          )
                        : _errorMessage != null
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.error_outline, size: 60, color: Colors.grey),
                                    const SizedBox(height: 16),
                                    Text(_errorMessage!),
                                    TextButton(
                                      onPressed: _fetchReports,
                                      child: Text("retry".tr()),
                                    )
                                  ],
                                ),
                              )
                            : reports.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.history, size: 70, color: Colors.grey.shade300),
                                        const SizedBox(height: 16),
                                        Text(
                                          'no_reports_yet'.tr(),
                                          style: TextStyle(color: Colors.grey.shade500, fontSize: 18),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.only(
                                        top: 30, left: 20, right: 20, bottom: 20),
                                    itemCount: reports.length,
                                    itemBuilder: (context, index) {
                                      return _buildReportCard(reports[index]);
                                    },
                                  ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    bool isExpanded = false;
    return StatefulBuilder(
      builder: (context, setState) {
        return GestureDetector(
          onTap: () {
            setState(() {
              isExpanded = !isExpanded;
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F9F9),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report['title']?.toString().tr() ?? report['type']?.toString().tr() ?? 'report'.tr(),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2D2D2D),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _localizeDigits(report['created_at'] != null 
                              ? DateFormat('MMM dd, yyyy at h:mm a').format(DateTime.parse(report['created_at']))
                              : report['date'] ?? ''),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getStatusBgColor(report['status'] ?? 'pending'),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              (report['status'] ?? 'pending').toString().tr(),
                              style: TextStyle(
                                color: _getStatusTextColor(report['status'] ?? 'pending'),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: Colors.grey.shade400,
                      size: 30,
                    ),
                  ],
                ),
                if (isExpanded) ...[
                  const SizedBox(height: 16),
                  Divider(color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  if (report['description'] != null && report['description'].toString().isNotEmpty) ...[
                    Text(
                      "${'description'.tr()}:",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report['description'].toString(),
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (report['location_text'] != null && report['location_text'].toString().isNotEmpty) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, size: 18, color: Color(0xFFD546F3)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            report['location_text'].toString(),
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (report['media'] != null || report['media_url'] != null || report['media_path'] != null) ...[
                    const SizedBox(height: 4),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final String mediaUrl = report['full_media_url'] ?? report['media_url'] ?? report['media_path'] ?? report['media'] ?? '';
                        String fullUrl = mediaUrl.trim();
                        final String baseHost = ApiConfig.baseUrl.replaceAll('/api', '');
                        
                        if (!fullUrl.startsWith('http')) {
                          fullUrl = fullUrl.replaceFirst('public/', '');
                          if (fullUrl.startsWith('/')) {
                            fullUrl = fullUrl.substring(1);
                          }
                          if (!fullUrl.startsWith('storage/')) {
                            fullUrl = 'storage/$fullUrl';
                          }
                          fullUrl = '$baseHost/$fullUrl';
                        }
                        
                        // Fix for Laravel returning APP_URL with localhost/127.0.0.1
                        if (fullUrl.startsWith('http://127.0.0.1/') ||
                            fullUrl.startsWith('http://localhost/') ||
                            fullUrl.startsWith('http://127.0.0.1:8000/') ||
                            fullUrl.startsWith('http://localhost:8000/')) {
                          fullUrl = fullUrl
                              .replaceFirst('http://127.0.0.1:8000/', '$baseHost/')
                              .replaceFirst('http://localhost:8000/', '$baseHost/')
                              .replaceFirst('http://127.0.0.1/', '$baseHost/')
                              .replaceFirst('http://localhost/', '$baseHost/');
                        }
                        
                        debugPrint("DEBUG: Opening report attachment URL = $fullUrl");
                        
                        final String lowerUrl = fullUrl.toLowerCase();
                        final bool isAudio = lowerUrl.contains('.wav') || 
                                             lowerUrl.contains('.mp3') || 
                                             lowerUrl.contains('.m4a') || 
                                             lowerUrl.contains('.aac') || 
                                             lowerUrl.contains('.ogg') ||
                                             lowerUrl.contains('.amr') ||
                                             lowerUrl.contains('.3gp');
                                             
                        if (isAudio) {
                          _showAudioPlayerBottomSheet(context, fullUrl);
                        } else {
                          try {
                            final Uri url = Uri.parse(fullUrl);
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          } catch (e) {
                            debugPrint("Error launching URL: $e");
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Could not open media')),
                              );
                            }
                          }
                        }
                      },
                      icon: const Icon(Icons.play_circle_fill, color: Colors.white, size: 20),
                      label: const Text('View Attachment', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD546F3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                  ]
                ],
              ],
            ),
          ),
        );
      }
    );
  }

  void _showAudioPlayerBottomSheet(BuildContext context, String url) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return AudioPlayerWidget(url: url);
      },
    );
  }
}

class AudioPlayerWidget extends StatefulWidget {
  final String url;
  const AudioPlayerWidget({super.key, required this.url});

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = true;
  bool _isPaused = false;
  bool _useNetworkSource = true;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _localFilePath;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      _audioPlayer.onDurationChanged.listen((d) {
        if (mounted) setState(() => _duration = d);
      });
      _audioPlayer.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      });
      _audioPlayer.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state == PlayerState.playing;
            _isLoading = false;
          });
        }
      });
      _audioPlayer.onPlayerComplete.listen((event) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _isPaused = false;
            _position = Duration.zero;
          });
        }
      });
      
      debugPrint("DEBUG: Resolving audio source for URL: ${widget.url}");
      
      // Try using direct streaming from URL first
      try {
        await _audioPlayer.setSource(UrlSource(widget.url));
        _useNetworkSource = true;
      } catch (networkError) {
        debugPrint("DEBUG: Direct network streaming failed: $networkError. Downloading locally.");
        final response = await http.get(Uri.parse(widget.url)).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final bytes = response.bodyBytes;
          final dir = await getTemporaryDirectory();
          final fileName = widget.url.split('/').last.split('?').first;
          final file = File('${dir.path}/temp_$fileName');
          await file.writeAsBytes(bytes);
          
          debugPrint("DEBUG: Audio file downloaded successfully to: ${file.path}");
          _localFilePath = file.path;
          await _audioPlayer.setSource(DeviceFileSource(file.path));
          _useNetworkSource = false;
        } else {
          throw Exception("Server returned status code: ${response.statusCode}");
        }
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _initError = null;
        });
      }
    } catch (e) {
      debugPrint("Error initializing audio: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _initError = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() {
        _isPaused = true;
      });
    } else {
      if (_isPaused) {
        await _audioPlayer.resume();
      } else {
        if (_useNetworkSource) {
          await _audioPlayer.play(UrlSource(widget.url));
        } else if (_localFilePath != null) {
          await _audioPlayer.play(DeviceFileSource(_localFilePath!));
        }
      }
      setState(() {
        _isPaused = false;
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = EasyLocalization.of(context)?.locale.languageCode == 'ar';
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          Text(
            isArabic ? "تشغيل التسجيل الصوتي" : "Play Voice Recording",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Color(0xFFD546F3)))
          else if (_initError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                isArabic ? "خطأ في تشغيل الصوت: $_initError" : "Error playing audio: $_initError",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
              ),
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 64,
                  color: const Color(0xFFD546F3),
                  icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                  onPressed: _togglePlayPause,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFFD546F3),
                inactiveTrackColor: Colors.grey[200],
                thumbColor: const Color(0xFFD546F3),
                trackHeight: 4,
              ),
              child: Slider(
                value: _position.inMilliseconds.toDouble(),
                max: _duration.inMilliseconds.toDouble() > 0 ? _duration.inMilliseconds.toDouble() : 1.0,
                onChanged: (value) async {
                  await _audioPlayer.seek(Duration(milliseconds: value.toInt()));
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(_position), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  Text(_formatDuration(_duration), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
