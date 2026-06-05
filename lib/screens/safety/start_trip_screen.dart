import 'package:flutter/material.dart';
import 'live_location_screen.dart';

class StartTripScreen extends StatefulWidget {
  const StartTripScreen({super.key});

  @override
  State<StartTripScreen> createState() => _StartTripScreenState();
}

class _StartTripScreenState extends State<StartTripScreen> {
  List<Map<String, dynamic>> watchers = [
    {
      'name': 'Mohamed Adel',
      'phone': '01551471747',
      'image': 'images/man.jpg',
      'selected': true,
    },
    {
      'name': 'Mohamed Adel',
      'phone': '01551471747',
      'image': 'images/man.jpg',
      'selected': false,
    },
    {
      'name': 'Mohamed Adel',
      'phone': '01551471747',
      'image': 'images/man.jpg',
      'selected': true,
    },
  ];

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
                padding: const EdgeInsets.only(top: 60, left: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios,
                          color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Start trip',
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
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  padding: const EdgeInsets.only(top: 30, left: 24, right: 24),
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                  colors: [
                                    Color(0xFF8E9EFE),
                                    Color(0xFFE040FB)
                                  ],
                                ).createShader(bounds),
                                child: const Text(
                                  'Enter Destination',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7F7F7),
                                  borderRadius: BorderRadius.circular(30),
                                  border:
                                      Border.all(color: Colors.grey.shade400),
                                ),
                                child: TextField(
                                  decoration: InputDecoration(
                                    hintText: 'Enter Destination',
                                    hintStyle: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 18,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 16),
                                    suffixIcon: const Icon(Icons.search,
                                        color: Colors.black54),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              ShaderMask(
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                  colors: [
                                    Color(0xFF8E9EFE),
                                    Color(0xFFE040FB)
                                  ],
                                ).createShader(bounds),
                                child: const Text(
                                  'Select your watcher',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'They will be notified and can view\nyour location .',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade700,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ...watchers.asMap().entries.map((entry) {
                                int index = entry.key;
                                Map<String, dynamic> watcher = entry.value;
                                return _buildWatcherCard(watcher, index);
                              }),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        height: 55,
                        margin: const EdgeInsets.only(bottom: 100),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCB30E0),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.blue, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFCB30E0)
                                  .withValues(alpha: 0.3),
                              spreadRadius: 1,
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LiveLocationScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'Start trip',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWatcherCard(Map<String, dynamic> watcher, int index) {
    return GestureDetector(
      onTap: () {
        setState(() {
          watchers[index]['selected'] = !watchers[index]['selected'];
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F9F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 65,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: AssetImage(watcher['image']),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    watcher['name'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    watcher['phone'],
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFD546F3),
                  width: 1.5,
                ),
              ),
              child: watcher['selected']
                  ? const Icon(
                      Icons.check,
                      color: Color(0xFFD546F3),
                      size: 24,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
