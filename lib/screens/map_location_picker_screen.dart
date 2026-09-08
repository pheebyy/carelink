import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

String buildAutoLocationLabel(String? rawLocation) {
  final trimmed = (rawLocation ?? '').trim();
  return trimmed.isEmpty ? 'Current location' : trimmed;
}

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
  GoogleMapController? _mapController;
  double? _latitude;
  double? _longitude;
  bool _isLoadingLocation = false;
  Set<Marker> _markers = {};
  bool _mapReady = false;
  
  static const defaultLatitude = -1.286389; // Nairobi center
  static const defaultLongitude = 36.817223;

  @override
  void initState() {
    super.initState();
    _latitude = widget.initialLatitude;
    _longitude = widget.initialLongitude;
    _locationNameController = TextEditingController(
      text: buildAutoLocationLabel(widget.initialLocationName),
    );
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _locationNameController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final result = await Geolocator.requestPermission();
        if (result == LocationPermission.denied) {
          // Use default location if permission denied
          _setDefaultLocation();
          return;
        }
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

      // Move camera to current location AFTER map is ready
      if (_mapReady) {
        _moveCameraToLocation(_latitude!, _longitude!);
      }
    } catch (e) {
      print('Error getting location: $e');
      setState(() => _isLoadingLocation = false);
      _setDefaultLocation();
    }
  }

  void _setDefaultLocation() {
    setState(() {
      _latitude = defaultLatitude;
      _longitude = defaultLongitude;
      _isLoadingLocation = false;
    });
    if (_mapReady) {
      _moveCameraToLocation(_latitude!, _longitude!);
    }
  }

  void _moveCameraToLocation(double latitude, double longitude) {
    if (_mapController == null) return;
    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(latitude, longitude),
          zoom: 15,
        ),
      ),
    );
    _addMarker(latitude, longitude);
  }

  void _addMarker(double latitude, double longitude) {
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('selected_location'),
          position: LatLng(latitude, longitude),
          infoWindow: const InfoWindow(
            title: 'Selected Location',
          ),
        ),
      };
      _latitude = latitude;
      _longitude = longitude;
    });
  }

  void _onMapTap(LatLng position) {
    _addMarker(position.latitude, position.longitude);
  }

  void _confirmLocation() {
    if (_latitude != null && _longitude != null) {
      final locationName = buildAutoLocationLabel(_locationNameController.text);
      Navigator.pop(context, {
        'latitude': _latitude,
        'longitude': _longitude,
        'locationName': locationName,
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to determine your current location')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Google Map
          Expanded(
            child: _isLoadingLocation
                ? const Center(child: CircularProgressIndicator())
                : _latitude != null && _longitude != null
                    ? GoogleMap(
                        onMapCreated: (controller) {
                          _mapController = controller;
                          setState(() => _mapReady = true);
                          // Now that map is ready, animate to location
                          _moveCameraToLocation(_latitude!, _longitude!);
                        },
                        initialCameraPosition: CameraPosition(
                          target: LatLng(_latitude!, _longitude!),
                          zoom: 15,
                        ),
                        markers: _markers,
                        onTap: _onMapTap,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        zoomControlsEnabled: true,
                        mapType: MapType.normal,
                      )
                    : Center(
                        child: Text(
                          'Could not retrieve location',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
          ),
          
          // Location info card
          if (_latitude != null && _longitude != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Latitude: ${_latitude?.toStringAsFixed(6)}, Longitude: ${_longitude?.toStringAsFixed(6)}\nTap map to place marker',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                ],
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
