import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
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
    // Request permissions
    await Permission.bluetooth.request();
    await Permission.location.request();
    try {
      await _bleService.startScan((device, name) {
        if (!_devices.any((d) => d['id'] == device.id.id)) {
          setState(() {
            _devices.add({'device': device, 'name': name, 'id': device.id.id});
          });
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Scan failed: $e';
      });
    } finally {
      setState(() {
        _scanning = false;
      });
    }
  }

  Future<void> _connect(BluetoothDevice device) async {
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      await _bleService.connectAndListen(device, (bpm) {
        setState(() {
          _bpm = bpm;
          _connectedDevice = device;
        });
      });
    } catch (e) {
      setState(() {
        _error = 'Connection failed: $e';
      });
    } finally {
      setState(() {
        _connecting = false;
      });
    }
  }

  Widget _buildDeviceList() {
    if (_devices.isEmpty) {
      return const Text('No devices found.');
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: _devices.length,
      itemBuilder: (context, index) {
        final d = _devices[index];
        return ListTile(
          title: Text(d['name'] ?? 'Unknown'),
          subtitle: Text(d['id']),
          trailing: ElevatedButton(
            onPressed: _connecting ? null : () => _connect(d['device']),
            child: const Text('Connect'),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vitals BLE Monitor')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_connectedDevice == null) ...[
              ElevatedButton(
                onPressed: _scanning ? null : _startScan,
                child: Text(_scanning ? 'Scanning...' : 'Scan for Devices'),
              ),
              const SizedBox(height: 16),
              Expanded(child: _buildDeviceList()),
            ] else ...[
              Text('Connected to: ${_connectedDevice!.name}'),
              const SizedBox(height: 16),
              Text(_bpm != null ? 'Heart Rate: $_bpm BPM' : 'Waiting for data...'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  _bleService.disconnect();
                  setState(() {
                    _connectedDevice = null;
                    _bpm = null;
                  });
                },
                child: const Text('Disconnect'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
