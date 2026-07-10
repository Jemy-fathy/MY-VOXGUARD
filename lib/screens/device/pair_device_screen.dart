import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:ui' as ui;
import '../../services/bluetooth_service.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide BluetoothService;
import 'pair_device2_screen.dart';

class PairDeviceScreen extends StatefulWidget {
  const PairDeviceScreen({super.key});

  @override
  _PairDeviceScreenState createState() => _PairDeviceScreenState();
}

class _PairDeviceScreenState extends State<PairDeviceScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final AppBluetoothService _bluetoothService = AppBluetoothService();
  List<ScanResult> _scanResults = [];
  StreamSubscription? _scanSubscription;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _initBluetooth();
  }

  Future<void> _initBluetooth() async {
    bool granted = await _bluetoothService.requestPermissions();
    if (granted) {
      _startScan();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bluetooth permissions are required.')),
      );
    }
  }

  void _startScan() {
    setState(() => _isScanning = true);
    _scanSubscription = _bluetoothService.scanResults().listen((results) {
      if (mounted) {
        setState(() {
          _scanResults = results.where((r) => r.device.platformName.isNotEmpty).toList();
        });
      }
    }, onDone: () {
      if (mounted) setState(() => _isScanning = false);
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scanSubscription?.cancel();
    _bluetoothService.stopScan();
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
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                textDirection: context.locale.languageCode == 'ar' ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 20
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'pair_device'.tr(),
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
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
                padding: const EdgeInsets.only(top: 150.0, left: 24.0, right: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildScanningIndicator(),
                    const SizedBox(height: 40),
                    _buildSectionTitle('available_devices'.tr()),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _scanResults.isEmpty
                          ? Center(
                              child: Text(
                                _isScanning ? 'searching'.tr() : 'no_devices_found'.tr(),
                                style: const TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: _scanResults.length,
                              itemBuilder: (context, index) {
                                final result = _scanResults[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: _buildDeviceCard(
                                    deviceName: result.device.platformName,
                                    onConnect: () async {
                                      await _bluetoothService.stopScan();
                                      
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (context) => const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      );

                                      bool success = await _bluetoothService.connectAndMonitor(result.device);
                                      
                                      if (context.mounted) Navigator.pop(context);

                                      if (success) {
                                        if (context.mounted) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => PairDevice2Screen(
                                                deviceName: result.device.platformName,
                                              ),
                                            ),
                                          );
                                        }
                                      } else {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Failed to connect to device.')),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                );
                              },
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
        if (_isScanning)
          AnimatedBuilder(
            animation: _animationController,
            builder: (_, child) => Transform.rotate(
              angle: _animationController.value * 2 * 3.14,
              child: child,
            ),
            child: const Icon(Icons.sync, color: Color(0xFFCB30E0), size: 24),
          ),
        const SizedBox(width: 12),
        Text(
          _isScanning ? 'scanning_for_devices'.tr() : 'scanning_stopped'.tr(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w300, color: Colors.black87),
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
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
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
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.watch, size: 150, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildDeviceCard({required String deviceName, required VoidCallback onConnect}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
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
                Text(deviceName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                Text('ready_to_pair'.tr(), style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onConnect,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCB30E0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 5,
            ),
            child: Text('connect'.tr(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

