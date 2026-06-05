import 'package:flutter/material.dart';
import '/screens/reports/report_history_screen.dart';
//import '../widgets/custom_bottom_nav.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class CreateReportScreen extends StatefulWidget {
  const CreateReportScreen({super.key});

  @override
  State<CreateReportScreen> createState() => _CreateReportScreenState();
}

class _CreateReportScreenState extends State<CreateReportScreen> {
  String? selectedIncidentType;
  final ImagePicker _picker = ImagePicker();
  File? _image;
  File? _video;

  Future<void> _pickImage() async {
    final XFile? selectedImage =
        await _picker.pickImage(source: ImageSource.gallery);

    if (selectedImage != null) {
      setState(() {
        _image = File(selectedImage.path);
      });
    }
  }

  Future<void> _pickVideo() async {
    final XFile? selectedVideo =
        await _picker.pickVideo(source: ImageSource.gallery);

    if (selectedVideo != null) {
      setState(() {
        _video = File(selectedVideo.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
     // bottomNavigationBar: const CustomBottomNavBar(currentIndex: 2),
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left,
                          color: Colors.white, size: 30),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Create Report',
                      style: TextStyle(
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
                        const Text(
                          'Incident Type',
                          style: TextStyle(
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
                        const Text(
                          'Description',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD546F3)),
                        ),
                        const SizedBox(height: 12),
                        _buildDescriptionField(),
                        const SizedBox(height: 24),
                        _buildActionButton('Send to police',
                            const Color(0xFFCB30E0), Colors.white, true),
                        const SizedBox(height: 16),
                        _buildActionButton('Send to Trusted', Colors.white,
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
          hint: const Text('Select Incident Type'),
          value: selectedIncidentType,
          items:
              ['Accident', 'Harassment', 'Theft', 'Other'].map((String value) {
            return DropdownMenuItem<String>(value: value, child: Text(value));
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
          'photo',
          Icons.image_outlined,
          onTap: _pickImage,
          selectedFile: _image,
        ),
        _buildMediaButton(
          'Video',
          Icons.ondemand_video_outlined,
          onTap: _pickVideo,
          selectedFile: _video,
          isVideo: true,
        ),
        _buildMediaButton('voice', Icons.mic_none),
      ],
    );
  }

  Widget _buildMediaButton(String label, IconData icon,
      {VoidCallback? onTap, File? selectedFile, bool isVideo = false}) {
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
                  ? (isVideo
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
                Text('Auto-Location Tag',
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                const Text('123 Main street , Anytown',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
      child: const TextField(
        maxLines: 4,
        decoration: InputDecoration(
          hintText: 'Describe the incident ......',
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
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
          onTap: () {
            // هنا تحط الأكشن بتاع الزرار
          },
          child: Center(
            child: Text(text,
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
