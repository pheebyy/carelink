import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service to scan, connect, and stream heart rate (and optionally SpO2) from BLE devices.
class BleVitalsService {
  StreamSubscription? _scanSub;
  BluetoothDevice? _device;
  StreamSubscription? _hrSub;
  bool _isConnected = false;
  int? _lastBpm;
  DateTime? _lastSyncTime;

  /// Start scanning for BLE devices advertising Heart Rate Service (0x180D).
  Future<void> startScan(Function(BluetoothDevice, String) onDeviceFound) async {
    _scanSub = FlutterBluePlus.scan().listen((scanResult) {
      final name = scanResult.device.platformName.isNotEmpty
          ? scanResult.device.platformName
          : 'Unknown';
      onDeviceFound(scanResult.device, name);
    });
  }

  /// Connect to device and subscribe to Heart Rate Measurement (0x2A37).
  Future<void> connectAndListen(
    BluetoothDevice device,
    void Function(int bpm) onData,
  ) async {
    _device = device;
    await device.connect(autoConnect: false);
    _isConnected = true;
    final services = await device.discoverServices();
    final hrService = services.firstWhere(
      (s) => s.uuid.toString().toLowerCase().contains('180d'),
      orElse: () => throw Exception('Heart Rate Service not found'),
    );
    final hrChar = hrService.characteristics.firstWhere(
      (c) => c.uuid.toString().toLowerCase().contains('2a37'),
      orElse: () => throw Exception('Heart Rate Measurement characteristic not found'),
    );
    await hrChar.setNotifyValue(true);
    _hrSub = hrChar.onValueReceived.listen((value) {
      final bpm = _decodeHeartRate(value);
      if (bpm != null) {
        onData(bpm);
        _maybeSyncToFirestore(bpm);
      }
    });
  }

  /// Decode Heart Rate Measurement characteristic (0x2A37) as per BLE spec.
  int? _decodeHeartRate(List<int> value) {
    if (value.isEmpty) return null;
    final flag = value[0];
    if (flag & 0x01 == 0) {
      return value[1]; // uint8
    } else {
      return value[1] | (value[2] << 8); // uint16
    }
  }

  /// Efficiently push heart rate to Firestore (throttled, only on change or interval)
  Future<void> _maybeSyncToFirestore(int bpm) async {
    final now = DateTime.now();
    // Only update if value changed or at least 20 seconds passed
    if (_lastBpm == bpm && _lastSyncTime != null && now.difference(_lastSyncTime!).inSeconds < 20) {
      return;
    }
    _lastBpm = bpm;
    _lastSyncTime = now;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = FirebaseFirestore.instance.collection('users').doc(user.uid);
    await doc.update({
      'vitals': {
        'heartRate': bpm,
        'timestamp': FieldValue.serverTimestamp(),
      }
    });
  }

  /// Stop scanning, disconnect, and clean up.
  Future<void> disconnect() async {
    await _hrSub?.cancel();
    if (_device != null && _isConnected) {
      await _device!.disconnect();
      _isConnected = false;
    }
    await _scanSub?.cancel();
  }
}