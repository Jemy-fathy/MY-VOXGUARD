import 'package:flutter/material.dart';
//import '../widgets/custom_bottom_nav.dart';

class ReportHistoryScreen extends StatefulWidget {
  const ReportHistoryScreen({super.key});

  @override
  State<ReportHistoryScreen> createState() => _ReportHistoryScreenState();
}

class _ReportHistoryScreenState extends State<ReportHistoryScreen> {
  // البيانات الوهمية للتقارير
  final List<Map<String, dynamic>> reports = [
    {
      'title': 'Harassment Incident',
      'date': 'Oct 26, 2023 at 4:15 PM',
      'status': 'Reviewed',
      'statusBgColor': const Color(0xFFEBC1F9),
      'statusTextColor': const Color(0xFFCA32DF),
    },
    {
      'title': 'Unsafe Area',
      'date': 'Oct 24, 2023 at 8:30 PM',
      'status': 'Pending',
      'statusBgColor': const Color(0xFFF1E9AA),
      'statusTextColor': const Color(0xFF757A43),
    },
    {
      'title': 'Verbal Harassment Incident',
      'date': 'Oct 26, 2023 at 4:15 PM',
      'status': 'Closed',
      'statusBgColor': const Color(0xFFCED3D7),
      'statusTextColor': const Color(0xFF333333),
    },
    {
      'title': 'Harassment Incident',
      'date': 'Oct 26, 2023 at 4:15 PM',
      'status': 'Action Taken',
      'statusBgColor': const Color(0xFFEBC1F9),
      'statusTextColor': const Color(0xFFCA32DF),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
     // bottomNavigationBar: const CustomBottomNavBar(currentIndex: 2),
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios,
                          color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Report history',
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
                      topLeft: Radius.circular(35),
                      topRight: Radius.circular(35),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(35),
                      topRight: Radius.circular(35),
                    ),
                    child: ListView.builder(
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
    return Container(
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report['title'],
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D2D2D),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  report['date'],
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
                    color: report['statusBgColor'],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    report['status'],
                    style: TextStyle(
                      color: report['statusTextColor'],
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.keyboard_arrow_down,
            color: Colors.grey.shade400,
            size: 30,
          ),
        ],
      ),
    );
  }
}
