import 'package:flutter/material.dart';

class ActivityLogScreen extends StatelessWidget {
  const ActivityLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: 250,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFF8E9EFE), Color(0xFFD546F3)],
              ),
            ),
          ),
          Column(
            children: [
              Container(
                height: 140,
                padding: const EdgeInsets.only(top: 50, left: 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      'Activity log',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold),
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
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, -2),
                      )
                    ],
                  ),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
                    children: [
                      _buildUnifiedCard(
                        imagePath: 'images/sos.png',
                        title: "SOS Event Triggered",
                        time: "Today , 9:41 AM",
                        description:
                            "Alert sent to emergency contacts and authorities.\nlocation : 123 main St.Anytown",
                        isSpecial: true,
                      ),
                      _buildUnifiedCard(
                        imagePath: 'images/Trip.png',
                        title: "Trip Started",
                        time: "yesterday at 8:30 PM",
                        description: "From: Home , to : city library",
                      ),
                      _buildUnifiedCard(
                        imagePath: 'images/Report copy.png',
                        title: "Report Submitted",
                        time: "July 18, 2024 at 8:30 PM",
                        description: "Incident report regarding harassment",
                      ),
                      _buildUnifiedCard(
                        icon: Icons.location_on_outlined,
                        title: "Location Shared",
                        time: "July 18, 2024 at 8:30 PM",
                        description: "Live location shared with shahd zahran",
                      ),
                      _buildUnifiedCard(
                        imagePath: 'images/call.png',
                        title: "Fake Call Initiated",
                        time: "July 18, 2024 at 8:30 PM",
                        description:
                            "Scheduled fake call received successfully",
                      ),
                      _buildUnifiedCard(
                        icon: Icons.watch_outlined,
                        title: "Wearable Trigger",
                        time: "July 18, 2024 at 8:30 PM",
                        description: "High heart-rate detected (145 bpm)",
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

  Widget _buildUnifiedCard({
    String? imagePath,
    IconData? icon,
    required String title,
    required String time,
    required String description,
    bool isSpecial = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isSpecial ? const Color(0xFFF9F2FF) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isSpecial ? 0.12 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 30,
                height: 30,
                child: imagePath != null
                    ? Image.asset(imagePath, fit: BoxFit.contain)
                    : Icon(icon, color: const Color(0xFFD546F3), size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      time,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14.5,
              color: Color(0xFF2E2E2E),
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],  
      ),
    );
  }
}