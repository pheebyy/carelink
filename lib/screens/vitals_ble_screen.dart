import 'package:flutter/material.dart';
import '../services/ble_vitals_service.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class VitalsBleScreen extends StatefulWidget {
  const VitalsBleScreen({Key? key}) : super(key: key);

  @override
  State<VitalsBleScreen> createState() => _VitalsBleScreenState();
}

class _VitalsBleScreenState extends State<VitalsBleScreen> {
  final BleVitalsService _bleService = BleVitalsService();
  List<Map<String, dynamic>> _devices = [];
  BluetoothDevice? _connectedDevice;
  int? _bpm;
  bool _scanning = false;
  bool _connecting = false;
  String? _error;
  bool _setupValid = false;

  @override
  void initState() {
    super.initState();
    _validateSetup();
  }

  Future<void> _validateSetup() async {
    final error = await _bleService.validateBluetoothSetup();
    setState(() {
      _setupValid = error == null;
      if (error != null) {
        _error = error;
      }
    });
  }

  @override
  void dispose() {
    _bleService.disconnect();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() {
      _devices.clear();
      _scanning = true;
      _error = null;
    });

    try {
      await _bleService.startScan((device, name) {
        if (!_devices.any((d) => d['id'] == device.remoteId.str)) {
          setState(() {
            _devices.add({
              'device': device,
              'name': name,
              'id': device.remoteId.str,
            });
          });
        }
      });

      await Future.delayed(const Duration(seconds: 15));
      await _bleService.stopScan();

      if (mounted) {
        setState(() => _scanning = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error =
              'Failed to scan for devices. Please check Bluetooth is enabled: $e';
          _scanning = false;
        });
      }
    }
  }

  Future<void> _connect(BluetoothDevice device) async {
    setState(() {
      _connecting = true;
      _error = null;
    });

    try {
      await _bleService.connectAndListen(device, (bpm) {
        if (mounted) {
          setState(() {
            _bpm = bpm;
            _connectedDevice = device;
          });
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connected! Reading heart rate...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error =
              'Failed to connect to device. Make sure it supports Heart Rate (0x180D). Error: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _connecting = false);
      }
    }
  }

  Widget _buildDeviceList() {
    if (_devices.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bluetooth_searching,
                  size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(_scanning ? 'Scanning...' : 'No devices found'),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        itemCount: _devices.length,
        itemBuilder: (context, index) {
          final d = _devices[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.favorite),
              title: Text(d['name'] ?? 'Unknown Device'),
              subtitle: Text(d['id']),
              trailing: ElevatedButton(
                onPressed: _connecting ? null : () => _connect(d['device']),
                child: Text(_connecting ? 'Connecting...' : 'Connect'),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Heart Rate Monitor'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Error message
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_error != null) const SizedBox(height: 16),

            // Setup validation
            if (!_setupValid)
              ElevatedButton(
                onPressed: _validateSetup,
                child: const Text('Retry Setup Check'),
              )
            else if (_connectedDevice == null) ...[
              // Scan for devices
              ElevatedButton.icon(
                onPressed: _scanning ? null : _startScan,
                icon: const Icon(Icons.bluetooth),
                label: Text(_scanning ? 'Scanning...' : 'Scan for Devices'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Available Devices:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildDeviceList(),
            ] else ...[
              // Connected state
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Connected to ${_connectedDevice!.platformName}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _bpm != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Heart Rate (BPM)'),
                                const SizedBox(height: 8),
                                Text(
                                  '$_bpm',
                                  style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ],
                            )
                          : const Text('Waiting for data...'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  _bleService.disconnect();
                  setState(() {
                    _connectedDevice = null;
                    _bpm = null;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Disconnect'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
