import 'dart:math';
import 'package:flutter/material.dart';
import '../safety/monitoring_screen.dart';

class PairDevice2Screen extends StatefulWidget {
  const PairDevice2Screen({Key? key}) : super(key: key);

  @override
  _PairDevice2ScreenState createState() => _PairDevice2ScreenState();
}

class _PairDevice2ScreenState extends State<PairDevice2Screen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.45,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF86A8E7), // Lighter blue/purple
                  Color(0xFFD161F0), // Magenta
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
                        color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Pair Device ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.65,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.only(top: 150.0, left: 24.0, right: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Scanning Indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _animationController,
                          builder: (_, child) {
                            return Transform.rotate(
                              angle: _animationController.value * 2 * pi,
                              child: child,
                            );
                          },
                          child: Image.asset(
                            'images/scanning.png',
                            width: 24,
                            height: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Scanning for devices',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w300,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [
                          Color(0xFF4983F6),
                          Color(0xFFC175F5),
                          Color(0xFFFBACB7),
                        ],
                      ).createShader(bounds),
                      child: const Text(
                        'Available device',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: ListView(
                              padding: EdgeInsets.zero,
                              children: [
                                _buildDeviceCard(
                                  name: 'Smartwix',
                                  status: 'Connected',
                                  isConnected: true,
                                ),
                                const SizedBox(height: 12),
                                _buildDeviceCard(
                                  name: 'Smartwix',
                                  status: 'ready to pair',
                                  isConnected: false,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // "Show monitoring" Button
                          Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFCB30E0),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF4983F6),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFFCB30E0).withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const MonitoringScreen(),
                                    ),
                                  );
                                },
                                child: const Center(
                                  child: Text(
                                    'Show monitoring',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.15,
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset(
                'images/smart watch.png',
                height: 320,
                width: 320,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 250,
                  width: 180,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                      child: Icon(Icons.watch, size: 80, color: Colors.grey)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard({
    required String name,
    required String status,
    required bool isConnected,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey[300]!, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              color: Color(0xFFF0D5F6),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Image.asset(
                'images/Bluetooth.png',
                width: 28,
                height: 28,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: isConnected ? Colors.white : const Color(0xFFCB30E0),
              borderRadius: BorderRadius.circular(20),
              border: isConnected
                  ? Border.all(color: Colors.grey[300]!, width: 1)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: isConnected
                      ? Colors.black.withOpacity(0.05)
                      : const Color(0xFFCB30E0).withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {},
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text(
                    isConnected ? 'Connected' : 'Connect',
                    style: TextStyle(
                      color: isConnected ? Colors.black : Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
