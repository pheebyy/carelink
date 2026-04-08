import 'package:cloud_firestore/cloud_firestore.dart';

class CaregiversAvailability {
  final String id;
  final String caregiverId;
  final List<DateTime> unavailableDates; // Dates when caregiver is NOT available
  final String status; // 'available', 'unavailable', 'on_break'
  final String? breakReason; // Why unavailable (e.g., "Vacation", "Sick leave")
  final Timestamp updatedAt;

  CaregiversAvailability({
    required this.id,
    required this.caregiverId,
    required this.unavailableDates,
    required this.status,
    required this.updatedAt,
    this.breakReason,
  });

  factory CaregiversAvailability.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final datesList = (data['unavailableDates'] as List?)?.cast<Timestamp>() ?? [];
    return CaregiversAvailability(
      id: doc.id,
      caregiverId: data['caregiverId'] as String? ?? '',
      unavailableDates: datesList.map((ts) => ts.toDate()).toList(),
      status: data['status'] as String? ?? 'available',
      breakReason: data['breakReason'] as String?,
      updatedAt: data['updatedAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'caregiverId': caregiverId,
      'unavailableDates': unavailableDates.map((date) => Timestamp.fromDate(date)).toList(),
      'status': status,
      'breakReason': breakReason,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  bool isAvailableOn(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    return !unavailableDates.any((d) => 
      d.year == dateOnly.year && 
      d.month == dateOnly.month && 
      d.day == dateOnly.day
    ) && status == 'available';
  }
}
