import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class AppBluetoothService {
  // Singleton pattern
  static final AppBluetoothService _instance = AppBluetoothService._internal();
  factory AppBluetoothService() => _instance;
  AppBluetoothService._internal();

  BluetoothDevice? connectedDevice;
  bool hasHeartRateService = false;
  final StreamController<int> _heartRateController = StreamController<int>.broadcast();
  Stream<int> get heartRateStream => _heartRateController.stream;
  StreamSubscription<List<int>>? _charSubscription;

  // UUIDs for standard Heart Rate Service and Measurement Characteristic
  static const String heartRateServiceUuid = "180d";
  static const String heartRateCharUuid = "2a37";

  /// Request necessary permissions for Bluetooth
  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    return statuses[Permission.bluetoothScan]!.isGranted &&
           statuses[Permission.bluetoothConnect]!.isGranted &&
           statuses[Permission.location]!.isGranted;
  }

  /// Start scanning for devices
  Stream<List<ScanResult>> scanResults() {
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    return FlutterBluePlus.scanResults;
  }

  /// Stop scanning
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  /// Connect to a device and monitor heart rate
  Future<bool> connectAndMonitor(BluetoothDevice device) async {
    try {
      await device.connect(autoConnect: false, timeout: const Duration(seconds: 10));
      connectedDevice = device;
      hasHeartRateService = false;
      
      // Discover services
      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        if (service.uuid.toString().toLowerCase().contains(heartRateServiceUuid)) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase().contains(heartRateCharUuid)) {
              // Enable notifications
              await characteristic.setNotifyValue(true);
              
              // Cancel any existing subscription
              await _charSubscription?.cancel();
              
              // Subscribe to changes
              _charSubscription = characteristic.lastValueStream.listen((value) {
                int hr = _parseHeartRate(value);
                if (hr > 0) {
                  _heartRateController.add(hr);
                }
              });
              hasHeartRateService = true;
              break;
            }
          }
        }
      }
      return true;
    } catch (e) {
      debugPrint("Error connecting/monitoring: $e");
      hasHeartRateService = false;
      return false;
    }
  }

  int _parseHeartRate(List<int> value) {
    if (value.isEmpty) return 0;
    int flags = value[0];
    bool isUint16 = (flags & 0x01) != 0;
    if (isUint16) {
      if (value.length >= 3) {
        return value[1] + (value[2] << 8);
      }
    } else {
      if (value.length >= 2) {
        return value[1];
      }
    }
    return 0;
  }

  /// Disconnect from current device
  Future<void> disconnectCurrentDevice() async {
    await _charSubscription?.cancel();
    _charSubscription = null;
    if (connectedDevice != null) {
      await connectedDevice!.disconnect();
      connectedDevice = null;
    }
  }

  /// Connect to a device (legacy/general)
  Future<void> connectToDevice(BluetoothDevice device) async {
    await device.connect(autoConnect: false);
  }

  /// Disconnect from a device (legacy/general)
  Future<void> disconnectDevice(BluetoothDevice device) async {
    await device.disconnect();
  }

  /// Discover services and characteristics (legacy/general)
  Future<List<BluetoothService>> discoverServices(BluetoothDevice device) async {
    return await device.discoverServices();
  }
}
