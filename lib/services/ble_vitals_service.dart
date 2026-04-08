import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Improved BLE Vitals Service with proper error handling and timeouts
class BleVitalsService {
  static const String _heartRateServiceUUID = '180d';
  static const String _heartRateMeasurementUUID = '2a37';
  static const Duration _connectionTimeout = Duration(seconds: 10);
  static const Duration _discoveryTimeout = Duration(seconds: 10);

  StreamSubscription? _scanSub;
  BluetoothDevice? _device;
  StreamSubscription? _hrSub;
  bool _isConnected = false;
  int? _lastBpm;
  DateTime? _lastSyncTime;

  /// Check Bluetooth availability and permissions
  Future<String?> validateBluetoothSetup() async {
    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        return 'Bluetooth is not supported on this device';
      }

      final state = FlutterBluePlus.adapterStateNow;
      if (state != BluetoothAdapterState.on) {
        return 'Bluetooth is turned off. Please enable it in settings';
      }

      final bluetoothPerm = await Permission.bluetooth.request();
      if (!bluetoothPerm.isGranted) {
        return 'Bluetooth permission denied. Please enable in settings';
      }

      final locationPerm = await Permission.location.request();
      if (!locationPerm.isGranted) {
        return 'Location permission denied. Required for Bluetooth scanning';
      }

      return null;
    } catch (e) {
      return 'Error checking Bluetooth setup: $e';
    }
  }

  /// Start scanning for BLE heart rate devices
  /// Timeout should be managed by the caller (recommended 15 seconds)
  Future<void> startScan(Function(BluetoothDevice, String) onDeviceFound) async {
    try {
      await _scanSub?.cancel();
      print('🔵 Starting BLE scan (timeout recommended: 15s)...');
      
      _scanSub = FlutterBluePlus.scan().listen(
        (scanResult) {
          final device = scanResult.device;
          final name = device.platformName.isNotEmpty
              ? device.platformName
              : 'Unknown Device (${device.remoteId})';
          print('📱 Found device: $name (RSSI: ${scanResult.rssi})');
          onDeviceFound(device, name);
        },
        onError: (error) {
          print('❌ Scan error: $error');
        },
      );
      print('✅ Scan started');
    } catch (e) {
      print('❌ Failed to start scan: $e');
      throw Exception('Failed to start BLE scan: $e');
    }
  }

  /// Stop scanning
  Future<void> stopScan() async {
    try {
      await _scanSub?.cancel();
      print('✅ Scan stopped');
    } catch (e) {
      print('❌ Error stopping scan: $e');
    }
  }

  /// Connect to device and subscribe to Heart Rate with timeout and retries
  Future<void> connectAndListen(
    BluetoothDevice device,
    void Function(int bpm) onData, {
    int maxRetries = 3,
  }) async {
    _device = device;
    int attempt = 0;

    while (attempt < maxRetries) {
      try {
        attempt++;
        print('🔌 Connection attempt $attempt/$maxRetries to ${device.platformName}');

        await device
            .connect(autoConnect: false, timeout: _connectionTimeout)
            .timeout(_connectionTimeout);

        _isConnected = true;
        print('✅ Connected to device');

        print('🔍 Discovering services...');
        final services = await device
            .discoverServices()
            .timeout(_discoveryTimeout);

        final hrService = services.firstWhere(
          (s) => _uuidMatches(s.uuid.str, _heartRateServiceUUID),
          orElse: () =>
              throw Exception('Heart Rate Service (0x180D) not found on device'),
        );

        print('✅ Found Heart Rate Service');

        final hrChar = hrService.characteristics.firstWhere(
          (c) => _uuidMatches(c.uuid.str, _heartRateMeasurementUUID),
          orElse: () => throw Exception(
              'Heart Rate Measurement characteristic (0x2A37) not found'),
        );

        print('✅ Found Heart Rate Measurement characteristic');

        await hrChar.setNotifyValue(true);
        print('✅ Notifications enabled');

        _hrSub = hrChar.onValueReceived.listen(
          (value) {
            final bpm = _decodeHeartRate(value);
            if (bpm != null && bpm > 0 && bpm < 250) {
              print('❤️  Heart Rate: $bpm BPM');
              onData(bpm);
              _maybeSyncToFirestore(bpm);
            }
          },
          onError: (error) {
            print('❌ Error reading heart rate: $error');
          },
        );

        print('✅ Listening to heart rate data');
        return;
      } catch (e) {
        print('❌ Connection attempt $attempt failed: $e');

        try {
          await device.disconnect();
        } catch (_) {}

        _isConnected = false;

        if (attempt >= maxRetries) {
          print('❌ Failed after $maxRetries attempts');
          throw Exception('Failed to connect after $maxRetries attempts: $e');
        }

        await Future.delayed(Duration(seconds: attempt));
      }
    }
  }

  /// UUID comparison (handles both full and short UUIDs)
  bool _uuidMatches(String uuid, String searchUuid) {
    final normalized = uuid.toLowerCase().replaceAll('-', '');
    final searchNorm = searchUuid.toLowerCase().replaceAll('-', '');
    return normalized.contains(searchNorm) ||
        searchNorm.contains(normalized);
  }

  /// Decode Heart Rate Measurement characteristic (0x2A37) as per BLE spec
  int? _decodeHeartRate(List<int> value) {
    if (value.isEmpty) return null;

    try {
      final flag = value[0];

      if (flag & 0x01 == 0) {
        return value.length > 1 ? value[1] : null;
      } else {
        return value.length > 2 ? value[1] | (value[2] << 8) : null;
      }
    } catch (e) {
      print('⚠️  Error decoding heart rate: $e');
      return null;
    }
  }

  /// Efficiently push heart rate to Firestore (throttled)
  Future<void> _maybeSyncToFirestore(int bpm) async {
    final now = DateTime.now();

    if (_lastBpm == bpm &&
        _lastSyncTime != null &&
        now.difference(_lastSyncTime!).inSeconds < 20) {
      return;
    }

    _lastBpm = bpm;
    _lastSyncTime = now;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'vitals': {
          'heartRate': bpm,
          'timestamp': FieldValue.serverTimestamp(),
        }
      });

      print('📲 Synced vitals to Firestore');
    } catch (e) {
      print('⚠️  Error syncing vitals: $e');
    }
  }

  /// Disconnect and clean up all resources
  Future<void> disconnect() async {
    try {
      await _hrSub?.cancel();
      _hrSub = null;

      if (_device != null && _isConnected) {
        await _device!.disconnect();
        _isConnected = false;
      }

      await _scanSub?.cancel();
      _scanSub = null;

      _device = null;
      print('✅ Disconnected from device');
    } catch (e) {
      print('⚠️  Error during disconnect: $e');
    }
  }

  bool isConnected() => _isConnected && _device != null;

  int? getLastBpm() => _lastBpm;
}