import 'package:flutter/material.dart';

class MonitoringScreen extends StatelessWidget {
  const MonitoringScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: Stack(
        children: [
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
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios,
                        color: Colors.white, size: 24),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Text(
                    'Monitoring',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.85,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(35),
                  topRight: Radius.circular(35),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, -5),
                  )
                ],
              ),
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                child: Column(
                  children: [
                    _buildHeartRateCard(),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        _buildStatusCard(
                          'Motion\nDetection',
                          'Still',
                          'images/Motion.png',
                          const Color(0xFFE843EE),
                        ),
                        const SizedBox(width: 16),
                        _buildStatusCard(
                          'Auto-SOS\nAlert',
                          'Armed',
                          'images/sos.png',
                          const Color(0xFFCA47EE),
                        ),
                      ],
                    ),
                    const SizedBox(height: 48),
                    const Text(
                      "Monitoring is active. we're watching out for you.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF9E9E9E),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildActionButton(context),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeartRateCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.black.withOpacity(0.04), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 28, top: 28, right: 28),
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
                  child: const Text(
                    'live heart rate',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFF3F3F3),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '85 BPM',
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFCB30E0),
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: const [
                    Text(
                      'Last 60 seconds',
                      style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF757575),
                          fontWeight: FontWeight.w500),
                    ),
                    SizedBox(width: 12),
                    Text(
                      '+2%',
                      style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFFCB30E0),
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(40),
              bottomRight: Radius.circular(40),
            ),
            child: Image.asset(
              'images/live heart.png',
              height: 220,
              width: double.infinity,
              fit: BoxFit.fitWidth,
              errorBuilder: (c, e, s) => Container(
                height: 220,
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.show_chart,
                    size: 80, color: Color(0xFFE843EE)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
      String title, String status, String assetPath, Color iconColor) {
    return Expanded(
      child: Container(
        height: 150,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F3F3),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.black.withOpacity(0.04), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF212121),
                height: 1.2,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Image.asset(
                  assetPath,
                  height: 45,
                  width: 45,
                  color: iconColor,
                  errorBuilder: (c, e, s) =>
                      Icon(Icons.flash_on, color: iconColor, size: 30),
                ),
                const SizedBox(width: 10),
                Text(
                  status,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF212121),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFFE843EE),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF4983F6), width: 2),
        boxShadow: [
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
          onTap: () {},
          borderRadius: BorderRadius.circular(15),
          child: const Center(
            child: Text(
              'Disable monitoring',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
