import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:geolocator/geolocator.dart';
import '/screens/reports/report_history_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart' as dio_lib;
import 'dart:ui' as ui;
import 'package:http_parser/http_parser.dart';
import '../../config/api_config.dart';

class CreateReportScreen extends StatefulWidget {
  final VoidCallback? onBackPressed;
  final VoidCallback? onReportSubmitted;
  const CreateReportScreen({super.key, this.onBackPressed, this.onReportSubmitted});

  @override
  State<CreateReportScreen> createState() => _CreateReportScreenState();
}

class _CreateReportScreenState extends State<CreateReportScreen> {
  String? selectedIncidentType;
  final ImagePicker _picker = ImagePicker();
  File? _image;
  File? _video;
  File? _voice;
  final TextEditingController _descriptionController = TextEditingController();
  bool _isLoading = false;
  bool _isPickingFile = false;
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  
  String _locationText = "searching...".tr();
  double _latitude = 30.0444;
  double _longitude = 31.2357;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locationText = "gps_disabled".tr());
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _locationText = "permission_denied".tr());
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });
        _getAddressFromLatLng(position.latitude, position.longitude);
      }
    } catch (e) {
      debugPrint("Error determining position in CreateReportScreen: $e");
    }
  }

  Future<void> _getAddressFromLatLng(double lat, double lon) async {
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1');
    try {
      final response = await http.get(url, headers: {
        'User-Agent': 'voxGuard',
        'Accept-Language': context.locale.languageCode,
      });
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String displayName = data['display_name'] ?? "Unknown Location";
        List<String> parts = displayName.split(',');
        if (mounted) {
          setState(() {
            _locationText = parts.length > 2 ? "${parts[0]}, ${parts[1]}" : displayName;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _locationText = "${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}");
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (selectedIncidentType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('please_select_incident_type'.tr())),
      );
      return;
    }

    if (_descriptionController.text.trim().length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Description must be at least 5 characters')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? prefs.getString('auth_token');

      if (token == null) {
        throw Exception("Authentication token missing. Please log in again.");
      }

      dio_lib.Dio dio = dio_lib.Dio();
      
      // Setup FormData
      Map<String, dynamic> formDataMap = {
        'type': selectedIncidentType!,
        'description': _descriptionController.text.trim(),
        'location_text': _locationText, 
        'latitude': _latitude.toString(),
        'longitude': _longitude.toString(),
      };

      // Helper to detect content type
      MediaType getMediaType(String path) {
        final ext = path.split('.').last.toLowerCase();
        if (ext == 'png') return MediaType('image', 'png');
        if (ext == 'jpg' || ext == 'jpeg') return MediaType('image', 'jpeg');
        if (ext == 'mp4') return MediaType('video', 'mp4');
        if (ext == 'm4a') return MediaType('audio', 'x-m4a');
        if (ext == 'mp3') return MediaType('audio', 'mpeg');
        if (ext == 'wav') return MediaType('audio', 'wav');
        return MediaType('application', 'octet-stream');
      }

      // Add media file if exists
      if (_video != null) {
        formDataMap['media'] = await dio_lib.MultipartFile.fromFile(
          _video!.path,
          filename: _video!.path.split('/').last,
          contentType: getMediaType(_video!.path),
        );
      } else if (_image != null) {
        formDataMap['media'] = await dio_lib.MultipartFile.fromFile(
          _image!.path,
          filename: _image!.path.split('/').last,
          contentType: getMediaType(_image!.path),
        );
      } else if (_voice != null) {
        formDataMap['media'] = await dio_lib.MultipartFile.fromFile(
          _voice!.path,
          filename: _voice!.path.split('/').last,
          contentType: getMediaType(_voice!.path),
        );
      }

      dio_lib.FormData formData = dio_lib.FormData.fromMap(formDataMap);

      debugPrint("Sending report to: ${ApiConfig.createIncident}");
      
      final response = await dio.post(
        ApiConfig.createIncident,
        data: formData,
        options: dio_lib.Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('activity_log_report_time', DateTime.now().toIso8601String());
        } catch (e) {
          debugPrint("Error saving report timestamp: $e");
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('report_sent_success'.tr())),
          );
          if (widget.onReportSubmitted != null) {
            widget.onReportSubmitted!();
          } else {
            Navigator.pop(context);
          }
        }
      }
    } on dio_lib.DioException catch (e) {
      debugPrint("Dio Error: ${e.response?.data}");
      if (e.response?.statusCode == 401) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('token');
        await prefs.remove('auth_token');
        await prefs.remove('user_id');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Session expired. Please log in again.')),
          );
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        }
        return;
      }
      String msg = "Dio Error: ";
      if (e.response?.data != null) {
        if (e.response?.data is Map) {
          msg += e.response?.data['message'] ?? e.response?.data.toString();
        } else {
          msg += e.response!.data.toString();
        }
      } else {
        msg += e.message ?? e.toString();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      debugPrint("General Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _pickImage() async {
    if (_isPickingFile) return;
    setState(() => _isPickingFile = true);
    debugPrint("Picking image...");
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50, maxWidth: 1080, maxHeight: 1080);
      if (file != null) {
        String path = file.path;
        if (path.startsWith('file://')) path = path.substring(7);
        setState(() => _image = File(path));
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    } finally {
      setState(() => _isPickingFile = false);
    }
  }

  Future<void> _pickVideo() async {
    if (_isPickingFile) return;
    setState(() => _isPickingFile = true);
    debugPrint("Picking video...");
    try {
      final XFile? file = await _picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 30));
      if (file != null) {
        String path = file.path;
        if (path.startsWith('file://')) path = path.substring(7);
        setState(() => _video = File(path));
      }
    } catch (e) {
      debugPrint("Error picking video: $e");
    } finally {
      setState(() => _isPickingFile = false);
    }
  }

  Future<void> _pickVoice() async {
    if (_isPickingFile) return;
    setState(() => _isPickingFile = true);
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _voice = File(result.files.single.path!);
        });
      }
    } catch (e) {
      debugPrint("Error picking voice: $e");
    } finally {
      setState(() => _isPickingFile = false);
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/report_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        const config = RecordConfig(
          encoder: AudioEncoder.aacLc,
        );
        await _audioRecorder.start(config, path: path);
        setState(() {
          _isRecording = true;
          _voice = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording... Tap again to stop')),
        );
      }
    } catch (e) {
      debugPrint("Start Recording Error: $e");
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        if (path != null) {
          String cleanedPath = path.startsWith('file://') ? path.substring(7) : path;
          _voice = File(cleanedPath);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording saved')),
      );
    } catch (e) {
      debugPrint("Stop Recording Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Container(
            height: 200,
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
                      onPressed: widget.onBackPressed ?? () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'create_report'.tr(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.history,
                          color: Colors.white, size: 28),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ReportHistoryScreen(),
                          ),
                        );
                      },
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
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'incident_type'.tr(),
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD546F3)),
                        ),
                        const SizedBox(height: 12),
                        _buildDropdown(),
                        const SizedBox(height: 24),
                        _buildMediaRow(),
                        const SizedBox(height: 24),
                        _buildLocationTile(),
                        const SizedBox(height: 24),
                        Text(
                          'description'.tr(),
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD546F3)),
                        ),
                        const SizedBox(height: 12),
                        _buildDescriptionField(),
                        const SizedBox(height: 30), 
                        _buildActionButton('send_to_trusted'.tr(), Colors.white,
                            Colors.black87, false),
                        const SizedBox(height: 20),
                      ],
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

  Widget _buildDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: Text('select_incident_type'.tr()),
          value: selectedIncidentType,
          items:
              ['accident', 'harassment', 'theft', 'other'].map((String key) {
            return DropdownMenuItem<String>(value: key, child: Text(key.tr()));
          }).toList(),
          onChanged: (newValue) =>
              setState(() => selectedIncidentType = newValue),
        ),
      ),
    );
  }

  Widget _buildMediaRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildMediaButton(
          'photo'.tr(),
          Icons.image_outlined,
          onTap: _pickImage,
          selectedFile: _image,
        ),
        _buildMediaButton(
          'video'.tr(),
          Icons.ondemand_video_outlined,
          onTap: _pickVideo,
          selectedFile: _video,
          isVideo: true,
        ),
        _buildMediaButton(
          'voice'.tr(),
          Icons.mic_none,
          onTap: _pickVoice,
          selectedFile: _voice,
          isAudio: true,
        ),
      ],
    );
  }

  Widget _buildMediaButton(String label, IconData icon,
      {VoidCallback? onTap, File? selectedFile, bool isVideo = false, bool isAudio = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 105,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            CircleAvatar(
              backgroundColor: selectedFile != null
                  ? const Color(0xFFE1BEE7)
                  : const Color(0xFFF3E5F5),
              radius: 25,
              child: selectedFile != null
                  ? (isVideo || isAudio
                      ? const Icon(Icons.check,
                          color: Color(0xFFD546F3), size: 30)
                      : ClipOval(
                          child: Image.file(
                            selectedFile,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        ))
                  : Icon(icon, color: const Color(0xFFD546F3), size: 28),
            ),
            const SizedBox(height: 12),
            Text(label,
                style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationTile() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                )
              ],
            ),
            child: const Icon(Icons.location_on,
                color: Color(0xFFD546F3), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('auto_location_tag'.tr(),
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                Text(_localizeDigits(_locationText),
                    style:
                        const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: TextField(
        controller: _descriptionController,
        maxLines: 4,
        textAlign: TextAlign.start,
        decoration: InputDecoration(
          hintText: 'describe_incident_hint'.tr(),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildActionButton(
      String text, Color bgColor, Color textColor, bool hasShadow) {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF4A80F1), width: 2),
        boxShadow: hasShadow
            ? [
                BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4))
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: _isLoading ? null : _submitReport,
          child: Center(
            child: _isLoading 
                ? const SizedBox(
                    width: 24, 
                    height: 24, 
                    child: CircularProgressIndicator(color: Colors.black87, strokeWidth: 2)
                  )
                : Text(text,
                    style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}
