import 'dart:math';
import 'package:flutter/material.dart';
import '../../screens/device/pair_device2_screen.dart';

class PairDeviceScreen extends StatefulWidget {
  const PairDeviceScreen({Key? key}) : super(key: key);

  @override
  _PairDeviceScreenState createState() => _PairDeviceScreenState();
}

class _PairDeviceScreenState extends State<PairDeviceScreen>
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
                colors: [Color(0xFF86A8E7), Color(0xFFD161F0)],
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
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  const Text(
                    'Pair Device',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600),
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
                    _buildScanningIndicator(),
                    const SizedBox(height: 40),
                    _buildSectionTitle('Available device'),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          _buildDeviceCard(
                            deviceName: 'Smartwix Pro',
                            onConnect: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const PairDevice2Screen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildDeviceCard(
                            deviceName: 'Smartwix Lite',
                            onConnect: () {},
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildWatchImage(context),
        ],
      ),
    );
  }

  Widget _buildScanningIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _animationController,
          builder: (_, child) => Transform.rotate(
            angle: _animationController.value * 2 * pi,
            child: child,
          ),
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
              fontSize: 18, fontWeight: FontWeight.w300, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFF4983F6), Color(0xFFC175F5), Color(0xFFFBACB7)],
      ).createShader(bounds),
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  Widget _buildWatchImage(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.15,
      left: 0,
      right: 0,
      child: Center(
        child: Image.asset(
          'images/smart watch.png',
          height: 320,
          width: 320,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.watch, size: 150, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildDeviceCard(
      {required String deviceName, required VoidCallback onConnect}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFF0D5F6),
            child: Icon(Icons.bluetooth, color: Color(0xFFCB30E0)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(deviceName,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600)),
                Text('ready to pair',
                    style:
                        TextStyle(fontSize: 14, color: Colors.grey.shade500)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onConnect,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCB30E0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              elevation: 5,
              shadowColor: const Color(0xFFCB30E0).withOpacity(0.4),
            ),
            child: const Text('Connect',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
