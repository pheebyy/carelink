import 'package:cloud_firestore/cloud_firestore.dart';
import '../Models/job_analytics_model.dart';

class JobAnalyticsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Get analytics for a caregiver
  Future<JobAnalytics?> getCaregiverAnalytics(String caregiverId) async {
    try {
      final doc = await _db.collection('job_analytics').doc(caregiverId).get();
      if (!doc.exists) {
        // Return default analytics if none exist
        return JobAnalytics(
          userId: caregiverId,
          totalJobsCompleted: 0,
          totalJobsAccepted: 0,
          completionRate: 0.0,
          averageRating: 0.0,
          totalReviews: 0,
          totalEarnings: 0.0,
          currentlyAcceptedJobs: 0,
          lastUpdated: Timestamp.now(),
        );
      }
      return JobAnalytics.fromDoc(doc);
    } catch (e) {
      print('🔥 Error getting analytics: $e');
      return null;
    }
  }

  /// Stream analytics (real-time)
  Stream<JobAnalytics?> streamCaregiverAnalytics(String caregiverId) {
    return _db.collection('job_analytics').doc(caregiverId).snapshots().map((doc) {
      if (!doc.exists) {
        return JobAnalytics(
          userId: caregiverId,
          totalJobsCompleted: 0,
          totalJobsAccepted: 0,
          completionRate: 0.0,
          averageRating: 0.0,
          totalReviews: 0,
          totalEarnings: 0.0,
          currentlyAcceptedJobs: 0,
          lastUpdated: Timestamp.now(),
        );
      }
      return JobAnalytics.fromDoc(doc);
    });
  }

  /// Update job completed count and calculate completion rate
  Future<void> incrementJobCompleted({
    required String caregiverId,
    required double earnings,
  }) async {
    try {
      final stats = await getCaregiverAnalytics(caregiverId);
      if (stats == null) return;

      final newCompleted = stats.totalJobsCompleted + 1;
      final newRate = stats.totalJobsAccepted > 0
          ? newCompleted / stats.totalJobsAccepted
          : 1.0;

      await _db.collection('job_analytics').doc(caregiverId).set({
        'totalJobsCompleted': newCompleted,
        'totalJobsAccepted': stats.totalJobsAccepted,
        'completionRate': newRate,
        'averageRating': stats.averageRating,
        'totalReviews': stats.totalReviews,
        'totalEarnings': stats.totalEarnings + earnings,
        'currentlyAcceptedJobs': (stats.currentlyAcceptedJobs - 1).max(0),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      print('✅ Job completion recorded for caregiver: $caregiverId');
    } catch (e) {
      print('🔥 Error incrementing job completed: $e');
      rethrow;
    }
  }

  /// Update when job is accepted
  Future<void> incrementJobAccepted(String caregiverId) async {
    try {
      final stats = await getCaregiverAnalytics(caregiverId);
      if (stats == null) return;

      await _db.collection('job_analytics').doc(caregiverId).set({
        'totalJobsCompleted': stats.totalJobsCompleted,
        'totalJobsAccepted': stats.totalJobsAccepted + 1,
        'completionRate': stats.completionRate,
        'averageRating': stats.averageRating,
        'totalReviews': stats.totalReviews,
        'totalEarnings': stats.totalEarnings,
        'currentlyAcceptedJobs': stats.currentlyAcceptedJobs + 1,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      print('✅ Job acceptance recorded for caregiver: $caregiverId');
    } catch (e) {
      print('🔥 Error incrementing job accepted: $e');
      rethrow;
    }
  }

  /// Update rating (called when new review is submitted)
  Future<void> updateAverageRating({
    required String caregiverId,
    required double newRating,
  }) async {
    try {
      final stats = await getCaregiverAnalytics(caregiverId);
      if (stats == null) return;

      final totalRating = (stats.averageRating * stats.totalReviews) + newRating;
      final newTotal = stats.totalReviews + 1;
      final newAverage = totalRating / newTotal;

      await _db.collection('job_analytics').doc(caregiverId).set({
        'totalJobsCompleted': stats.totalJobsCompleted,
        'totalJobsAccepted': stats.totalJobsAccepted,
        'completionRate': stats.completionRate,
        'averageRating': newAverage,
        'totalReviews': newTotal,
        'totalEarnings': stats.totalEarnings,
        'currentlyAcceptedJobs': stats.currentlyAcceptedJobs,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      print('✅ Rating updated for caregiver: $caregiverId - New avg: $newAverage');
    } catch (e) {
      print('🔥 Error updating average rating: $e');
      rethrow;
    }
  }

  /// Get top caregivers by rating
  Future<List<String>> getTopCaregiversByRating({
    int limit = 10,
    double minRating = 4.0,
  }) async {
    try {
      final snapshot = await _db
          .collection('job_analytics')
          .where('averageRating', isGreaterThanOrEqualTo: minRating)
          .where('totalReviews', isGreaterThanOrEqualTo: 5)
          .orderBy('averageRating', descending: true)
          .orderBy('totalReviews', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print('🔥 Error getting top caregivers: $e');
      return [];
    }
  }

  /// Get top caregivers by earnings
  Future<List<String>> getTopCaregiversByEarnings({
    int limit = 10,
    int minJobsCompleted = 10,
  }) async {
    try {
      final snapshot = await _db
          .collection('job_analytics')
          .where('totalJobsCompleted', isGreaterThanOrEqualTo: minJobsCompleted)
          .orderBy('totalEarnings', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print('🔥 Error getting top earners: $e');
      return [];
    }
  }

  /// Get all caregivers sorted by rating
  Future<List<String>> getCaregiversByRating({int limit = 50}) async {
    try {
      final snapshot = await _db
          .collection('job_analytics')
          .where('totalReviews', isGreaterThan: 0)
          .orderBy('averageRating', descending: true)
          .orderBy('totalReviews', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print('🔥 Error getting caregivers by rating: $e');
      return [];
    }
  }

  /// Update when job is canceled (decrement accepted jobs)
  Future<void> decrementCurrentlyAcceptedJobs(String caregiverId) async {
    try {
      final stats = await getCaregiverAnalytics(caregiverId);
      if (stats == null) return;

      await _db.collection('job_analytics').doc(caregiverId).set({
        'totalJobsCompleted': stats.totalJobsCompleted,
        'totalJobsAccepted': stats.totalJobsAccepted,
        'completionRate': stats.completionRate,
        'averageRating': stats.averageRating,
        'totalReviews': stats.totalReviews,
        'totalEarnings': stats.totalEarnings,
        'currentlyAcceptedJobs': (stats.currentlyAcceptedJobs - 1).max(0),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      print('✅ Accepted job count decremented for caregiver: $caregiverId');
    } catch (e) {
      print('🔥 Error decrementing accepted jobs: $e');
      rethrow;
    }
  }
}

/// Extension to ensure non-negative values
extension IntExtension on int {
  int max(int other) => this > other ? this : other;
}
