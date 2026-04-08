import 'package:cloud_firestore/cloud_firestore.dart';
import '../Models/availability_model.dart';

class AvailabilityService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Create or update caregiver availability
  Future<void> setAvailability({
    required String caregiverId,
    required List<DateTime> unavailableDates,
    required String status, // 'available', 'unavailable', 'on_break'
    String? breakReason,
  }) async {
    try {
      await _db.collection('caregiver_availability').doc(caregiverId).set({
        'caregiverId': caregiverId,
        'unavailableDates': unavailableDates.map((d) => Timestamp.fromDate(d)).toList(),
        'status': status,
        'breakReason': breakReason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Availability updated for caregiver: $caregiverId');
    } catch (e) {
      print('🔥 Error setting availability: $e');
      rethrow;
    }
  }

  /// Block specific dates for a caregiver
  Future<void> blockDates({
    required String caregiverId,
    required List<DateTime> datesToBlock,
    String? reason,
  }) async {
    try {
      final doc = await _db.collection('caregiver_availability').doc(caregiverId).get();
      final availability = doc.exists
          ? CaregiversAvailability.fromDoc(doc)
          : CaregiversAvailability(
              id: caregiverId,
              caregiverId: caregiverId,
              unavailableDates: [],
              status: 'available',
              updatedAt: Timestamp.now(),
            );

      // Merge new dates with existing unavailable dates
      final allUnavailable = [...availability.unavailableDates, ...datesToBlock];
      // Remove duplicates
      final uniqueDates = allUnavailable.toSet().toList();

      await _db.collection('caregiver_availability').doc(caregiverId).set({
        'caregiverId': caregiverId,
        'unavailableDates': uniqueDates.map((d) => Timestamp.fromDate(d)).toList(),
        'status': availability.status,
        'breakReason': reason ?? availability.breakReason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Dates blocked for caregiver: $caregiverId');
    } catch (e) {
      print('🔥 Error blocking dates: $e');
      rethrow;
    }
  }

  /// Unblock specific dates
  Future<void> unblockDates({
    required String caregiverId,
    required List<DateTime> datesToUnblock,
  }) async {
    try {
      final doc = await _db.collection('caregiver_availability').doc(caregiverId).get();
      if (!doc.exists) return;

      final availability = CaregiversAvailability.fromDoc(doc);
      final remaining = availability.unavailableDates
          .where((date) =>
              !datesToUnblock.any((d) =>
                  d.year == date.year &&
                  d.month == date.month &&
                  d.day == date.day))
          .toList();

      await _db.collection('caregiver_availability').doc(caregiverId).update({
        'unavailableDates': remaining.map((d) => Timestamp.fromDate(d)).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Dates unblocked for caregiver: $caregiverId');
    } catch (e) {
      print('🔥 Error unblocking dates: $e');
      rethrow;
    }
  }

  /// Get caregiver availability
  Future<CaregiversAvailability?> getAvailability(String caregiverId) async {
    try {
      final doc = await _db.collection('caregiver_availability').doc(caregiverId).get();
      if (!doc.exists) return null;
      return CaregiversAvailability.fromDoc(doc);
    } catch (e) {
      print('🔥 Error getting availability: $e');
      return null;
    }
  }

  /// Stream caregiver availability (real-time)
  Stream<CaregiversAvailability?> streamAvailability(String caregiverId) {
    return _db
        .collection('caregiver_availability')
        .doc(caregiverId)
        .snapshots()
        .map((doc) => doc.exists ? CaregiversAvailability.fromDoc(doc) : null);
  }

  /// Check if caregiver is available on a specific date
  Future<bool> isAvailableOn({
    required String caregiverId,
    required DateTime date,
  }) async {
    try {
      final availability = await getAvailability(caregiverId);
      if (availability == null) return true; // No availability record = always available

      return availability.isAvailableOn(date);
    } catch (e) {
      print('🔥 Error checking availability: $e');
      return false;
    }
  }

  /// Get all available caregivers for a date (for job matching)
  Future<List<String>> getAvailableCaregivers(DateTime date) async {
    try {
      final snapshot = await _db
          .collection('caregiver_availability')
          .where('status', isEqualTo: 'available')
          .get();

      final available = <String>[];
      for (var doc in snapshot.docs) {
        final availability = CaregiversAvailability.fromDoc(doc);
        if (availability.isAvailableOn(date)) {
          available.add(availability.caregiverId);
        }
      }

      return available;
    } catch (e) {
      print('🔥 Error getting available caregivers: $e');
      return [];
    }
  }

  /// Set caregiver status (available, unavailable, on_break)
  Future<void> setStatus({
    required String caregiverId,
    required String status,
    String? breakReason,
  }) async {
    try {
      final doc = await _db.collection('caregiver_availability').doc(caregiverId).get();
      final availability = doc.exists
          ? CaregiversAvailability.fromDoc(doc)
          : CaregiversAvailability(
              id: caregiverId,
              caregiverId: caregiverId,
              unavailableDates: [],
              status: 'available',
              updatedAt: Timestamp.now(),
            );

      await _db.collection('caregiver_availability').doc(caregiverId).set({
        'caregiverId': caregiverId,
        'unavailableDates': availability.unavailableDates.map((d) => Timestamp.fromDate(d)).toList(),
        'status': status,
        'breakReason': breakReason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Status updated for caregiver: $caregiverId - $status');
    } catch (e) {
      print('🔥 Error setting status: $e');
      rethrow;
    }
  }
}
