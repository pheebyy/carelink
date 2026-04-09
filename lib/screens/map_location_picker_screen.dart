import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Map Location Picker Screen
class MapLocationPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialLocationName;

  const MapLocationPickerScreen({
    Key? key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialLocationName,
  }) : super(key: key);

  @override
  State<MapLocationPickerScreen> createState() => _MapLocationPickerScreenState();
}

class _MapLocationPickerScreenState extends State<MapLocationPickerScreen> {
  late final TextEditingController _locationNameController;
  double? _latitude;
  double? _longitude;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _latitude = widget.initialLatitude;
    _longitude = widget.initialLongitude;
    _locationNameController = TextEditingController(
      text: widget.initialLocationName ?? '',
    );
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _locationNameController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final result = await Geolocator.requestPermission();
        if (result == LocationPermission.denied) return;
      }

      setState(() => _isLoadingLocation = true);

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _isLoadingLocation = false;
      });
    } catch (e) {
      setState(() => _isLoadingLocation = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get current location')),
        );
      }
    }
  }

  void _confirmLocation() {
    final locationName = _locationNameController.text.trim();
    if (_latitude != null && _longitude != null && locationName.isNotEmpty) {
      Navigator.pop(context, {
        'latitude': _latitude,
        'longitude': _longitude,
        'locationName': locationName,
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a location name')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // Map placeholder - uses geolocator data
          Expanded(
            child: Container(
              color: Colors.grey.shade200,
              child: _isLoadingLocation
                  ? const Center(child: CircularProgressIndicator())
                  : _latitude != null && _longitude != null
                      ? Stack(
                          children: [
                            // Map area (simplified - shows current position info)
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 80,
                                    color: Colors.red,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Current Location',
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Latitude: ${_latitude?.toStringAsFixed(6)}',
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                  Text(
                                    'Longitude: ${_longitude?.toStringAsFixed(6)}',
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                  const SizedBox(height: 24),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.blue),
                                    ),
                                    child: const Text(
                                      'In production, integrate with:\n• Google Maps API\n• Mapbox\n• Leaflet\n\nFor quick testing, enter location name below →',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Center(
                          child: Text(
                            'Could not retrieve location',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
            ),
          ),
          // Location name input and confirmation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _locationNameController,
                  decoration: InputDecoration(
                    labelText: 'Location Name',
                    hintText: 'e.g., Downtown Nairobi, Westlands',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _confirmLocation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Confirm Location',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
