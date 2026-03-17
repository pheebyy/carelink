import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:geolocator/geolocator.dart';

class LocationTrackingService {
  LocationTrackingService._();

  static final LocationTrackingService instance = LocationTrackingService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription<Position>? _positionSubscription;
  String? _trackedUid;

  bool get isTracking => _positionSubscription != null;

  Future<Position> getCurrentPosition() async {
    await _ensureLocationReady();

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  Future<void> startTracking(String uid) async {
    if (uid.isEmpty) return;

    await _ensureLocationReady();

    if (_trackedUid == uid && _positionSubscription != null) {
      return;
    }

    await stopTracking();

    final initial = await getCurrentPosition();
    await _updateUserLocation(uid, initial);

    _trackedUid = uid;
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      ),
    ).listen(
      (position) async {
        await _updateUserLocation(uid, position);
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Location tracking stream error: $error');
      },
    );
  }

  Future<void> stopTracking() async {
    final uid = _trackedUid;

    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _trackedUid = null;

    if (uid != null && uid.isNotEmpty) {
      await _db.collection('users').doc(uid).set({
        'gpsTrackingActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> _updateUserLocation(String uid, Position position) async {
    final geoPoint = GeoPoint(position.latitude, position.longitude);
    final geoData = GeoFirePoint(geoPoint).data;

    await _db.collection('users').doc(uid).set({
      'geo': geoData,
      'gpsTrackingEnabled': true,
      'gpsTrackingActive': true,
      'lastKnownLocation': {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'heading': position.heading,
        'speed': position.speed,
      },
      'lastLocationUpdatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _ensureLocationReady() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled on this device.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Location permission denied.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission permanently denied. Enable it in device settings.',
      );
    }
  }
}
