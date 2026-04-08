import 'package:cloud_firestore/cloud_firestore.dart';
import '../Models/Job_model.dart';
import '../Models/review_model.dart';
import 'notification_service.dart';
import 'job_analytics_service.dart';

/// Service for managing job operations including posting, completion, and reviews
class JobService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService.instance;
  final JobAnalyticsService _analyticsService = JobAnalyticsService();

  // ==========================================
  // 💼 JOB MANAGEMENT
  // ==========================================

  /// Hire a caregiver for a job (client action)
  Future<void> hireCaregiver({
    required String jobId,
    required String caregiverId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      await _db.collection('jobs').doc(jobId).update({
        'caregiverId': caregiverId,
        'status': 'hired',
        'caregiverAccepted': false,
        'startDate': startDate != null ? Timestamp.fromDate(startDate) : null,
        'endDate': endDate != null ? Timestamp.fromDate(endDate) : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Caregiver hired for job: $jobId');
    } catch (e) {
      print('🔥 Error hiring caregiver: $e');
      rethrow;
    }
  }

  /// Caregiver accepts job (caregiver action)
  Future<void> acceptJob(String jobId) async {
    try {
      // Get job details for notification
      final jobDoc = await _db.collection('jobs').doc(jobId).get();
      final jobData = jobDoc.data();
      final jobTitle = jobData?['title'] ?? 'Job';
      final clientId = jobData?['clientId'] ?? '';
      final caregiverId = jobData?['caregiverId'] ?? '';

      await _db.collection('jobs').doc(jobId).update({
        'caregiverAccepted': true,
        'status': 'in-progress', // Automatically transition to in-progress
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Track analytics: Caregiver accepted job
      if (caregiverId.isNotEmpty) {
        try {
          await _analyticsService.incrementJobAccepted(caregiverId);
        } catch (e) {
          print('⚠️ Warning: Could not update analytics: $e');
        }
      }

      // Notify client that caregiver accepted
      if (clientId.isNotEmpty) {
        try {
          await _notificationService.createJobNotification(
            userId: clientId,
            type: 'job_accepted',
            title: 'Job Accepted!',
            message: 'A caregiver has accepted your $jobTitle job. Work gets started soon!',
            jobId: jobId,
            relatedUserId: caregiverId,
          );
        } catch (e) {
          print('⚠️ Warning: Could not send notification: $e');
        }
      }

      print('✅ Caregiver accepted job: $jobId');
    } catch (e) {
      print('🔥 Error accepting job: $e');
      rethrow;
    }
  }

  /// Caregiver declines job after being hired
  Future<void> declineJob(String jobId, String caregiverId) async {
    try {
      await _db.collection('jobs').doc(jobId).update({
        'caregiverId': null,
        'caregiverAccepted': false,
        'status': 'open', // Back to open for other caregivers
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Caregiver declined job: $jobId');
    } catch (e) {
      print('🔥 Error declining job: $e');
      rethrow;
    }
  }

  /// Caregiver confirms job completion
  Future<void> confirmCompletion(String jobId) async {
    try {
      final job = await _db.collection('jobs').doc(jobId).get();
      final data = job.data() ?? {};
      
      bool bothConfirmed = (data['clientConfirmedCompletion'] ?? false) || 
                          data['caregiverConfirmedCompletion'] == true;

      final update = {
        'caregiverConfirmedCompletion': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // If both confirmed, mark job as completed
      if (bothConfirmed) {
        update['status'] = 'completed';
        update['completedAt'] = FieldValue.serverTimestamp();

        // Track job completion analytics
        final caregiverId = data['caregiverId'] as String?;
        final clientId = data['clientId'] as String?;
        final jobTitle = data['title'] as String? ?? 'Job';
        final budget = data['budget'] as num? ?? 0;

        await _db.collection('jobs').doc(jobId).update(update);

        // Update analytics if we have caregiver info
        if (caregiverId != null && caregiverId.isNotEmpty) {
          try {
            await _analyticsService.incrementJobCompleted(
              caregiverId: caregiverId,
              earnings: budget.toDouble(),
            );
          } catch (e) {
            print('⚠️ Warning: Could not update completion analytics: $e');
          }
        }

        // Notify client job is completed
        if (clientId != null && clientId.isNotEmpty) {
          try {
            await _notificationService.createJobNotification(
              userId: clientId,
              type: 'job_completed',
              title: 'Job Completed!',
              message: '$jobTitle has been completed by your caregiver. Please review your experience.',
              jobId: jobId,
              relatedUserId: caregiverId,
            );
          } catch (e) {
            print('⚠️ Warning: Could not send completion notification: $e');
          }
        }
      } else {
        await _db.collection('jobs').doc(jobId).update(update);
      }

      print('✅ Caregiver confirmed completion for job: $jobId');
    } catch (e) {
      print('🔥 Error confirming completion: $e');
      rethrow;
    }
  }

  /// Client confirms job completion
  Future<void> clientConfirmCompletion(String jobId) async {
    try {
      final job = await _db.collection('jobs').doc(jobId).get();
      final data = job.data() ?? {};
      
      bool bothConfirmed = (data['caregiverConfirmedCompletion'] ?? false) || 
                          data['clientConfirmedCompletion'] == true;

      final update = {
        'clientConfirmedCompletion': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // If both confirmed, mark job as completed
      if (bothConfirmed) {
        update['status'] = 'completed';
        update['completedAt'] = FieldValue.serverTimestamp();

        // Track job completion analytics
        final caregiverId = data['caregiverId'] as String?;
        final clientId = data['clientId'] as String?;
        final jobTitle = data['title'] as String? ?? 'Job';
        final budget = data['budget'] as num? ?? 0;

        await _db.collection('jobs').doc(jobId).update(update);

        // Update analytics if we have caregiver info
        if (caregiverId != null && caregiverId.isNotEmpty) {
          try {
            await _analyticsService.incrementJobCompleted(
              caregiverId: caregiverId,
              earnings: budget.toDouble(),
            );
          } catch (e) {
            print('⚠️ Warning: Could not update completion analytics: $e');
          }
        }

        // Notify caregiver job is marked complete
        if (caregiverId != null && caregiverId.isNotEmpty) {
          try {
            await _notificationService.createJobNotification(
              userId: caregiverId,
              type: 'job_completed',
              title: 'Completion Confirmed!',
              message: 'Your client has confirmed completion of $jobTitle. Thank you!',
              jobId: jobId,
              relatedUserId: clientId,
            );
          } catch (e) {
            print('⚠️ Warning: Could not send completion notification: $e');
          }
        }
      } else {
        await _db.collection('jobs').doc(jobId).update(update);
      }

      print('✅ Client confirmed completion for job: $jobId');
    } catch (e) {
      print('🔥 Error confirming completion: $e');
      rethrow;
    }
  }

  /// Cancel a job with optional refund reason
  Future<void> cancelJob(String jobId, String reason) async {
    try {
      await _db.collection('jobs').doc(jobId).update({
        'status': 'canceled',
        'canceledAt': FieldValue.serverTimestamp(),
        'cancelReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Job canceled: $jobId - Reason: $reason');
    } catch (e) {
      print('🔥 Error canceling job: $e');
      rethrow;
    }
  }

  // ==========================================
  // ⭐ REVIEWS & RATINGS
  // ==========================================

  /// Submit a review for a completed job
  Future<String> submitReview({
    required String jobId,
    required String reviewerId,
    required String revieweeId,
    required String reviewerRole, // 'client' or 'caregiver'
    required double rating, // 1-5
    required String comment,
  }) async {
    try {
      if (rating < 1 || rating > 5) {
        throw Exception('Rating must be between 1 and 5');
      }
      if (comment.isEmpty || comment.length < 10) {
        throw Exception('Comment must be at least 10 characters');
      }

      final ref = await _db.collection('reviews').add({
        'jobId': jobId,
        'reviewerId': reviewerId,
        'revieweeId': revieweeId,
        'reviewerRole': reviewerRole,
        'rating': rating,
        'comment': comment,
        'createdAt': FieldValue.serverTimestamp(),
        'isFlagged': false,
      });

      // Update analytics with new rating for caregiver
      try {
        await _analyticsService.updateAverageRating(
          caregiverId: revieweeId,
          newRating: rating,
        );
      } catch (e) {
        print('⚠️ Warning: Could not update rating analytics: $e');
      }

      // Notify reviewee about the review
      try {
        final reviewerRoleDisplay = reviewerRole == 'client' ? 'Your Client' : 'Your Caregiver';
        await _notificationService.createJobNotification(
          userId: revieweeId,
          type: 'review_submitted',
          title: 'You Received a Review!',
          message: '$reviewerRoleDisplay gave you a ${rating.toStringAsFixed(1)}★ review.',
          jobId: jobId,
          relatedUserId: reviewerId,
        );
      } catch (e) {
        print('⚠️ Warning: Could not send review notification: $e');
      }

      print('✅ Review submitted for job: $jobId');
      return ref.id;
    } catch (e) {
      print('🔥 Error submitting review: $e');
      rethrow;
    }
  }

  /// Get all reviews for a user
  Future<UserRatings> getUserRatings(String userId) async {
    try {
      final snapshot = await _db
          .collection('reviews')
          .where('revieweeId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      if (snapshot.docs.isEmpty) {
        return UserRatings(
          userId: userId,
          averageRating: 0,
          totalReviews: 0,
          ratingDistribution: {},
          recentReviews: [],
        );
      }

      final reviews = snapshot.docs.map((doc) => ReviewModel.fromDoc(doc)).toList();
      
      // Calculate aggregate
      double totalRating = 0;
      Map<int, int> distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

      for (var review in reviews) {
        totalRating += review.rating;
        distribution[review.rating.toInt()] = (distribution[review.rating.toInt()] ?? 0) + 1;
      }

      final averageRating = totalRating / reviews.length;

      return UserRatings(
        userId: userId,
        averageRating: averageRating,
        totalReviews: reviews.length,
        ratingDistribution: distribution,
        recentReviews: reviews,
      );
    } catch (e) {
      print('🔥 Error getting user ratings: $e');
      rethrow;
    }
  }

  /// Stream user ratings (real-time updates)
  Stream<UserRatings> streamUserRatings(String userId) {
    return _db
        .collection('reviews')
        .where('revieweeId', isEqualTo: userId)
        .snapshots()
        .asyncMap((snapshot) async {
      if (snapshot.docs.isEmpty) {
        return UserRatings(
          userId: userId,
          averageRating: 0,
          totalReviews: 0,
          ratingDistribution: {},
          recentReviews: [],
        );
      }

      final reviews = snapshot.docs.map((doc) => ReviewModel.fromDoc(doc)).toList();
      
      double totalRating = 0;
      Map<int, int> distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

      for (var review in reviews) {
        totalRating += review.rating;
        distribution[review.rating.toInt()] = (distribution[review.rating.toInt()] ?? 0) + 1;
      }

      return UserRatings(
        userId: userId,
        averageRating: reviews.isNotEmpty ? totalRating / reviews.length : 0,
        totalReviews: reviews.length,
        ratingDistribution: distribution,
        recentReviews: reviews.take(10).toList(),
      );
    });
  }

  /// Check if user has already reviewed a job
  Future<bool> hasUserReviewedJob(String jobId, String reviewerId) async {
    try {
      final snapshot = await _db
          .collection('reviews')
          .where('jobId', isEqualTo: jobId)
          .where('reviewerId', isEqualTo: reviewerId)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('🔥 Error checking review: $e');
      return false;
    }
  }

  // ==========================================
  // 💰 JOB PAYMENT INTEGRATION
  // ==========================================

  /// Link a payment transaction to a job (triggers after completion)
  Future<void> linkPaymentToJob(String jobId, String paymentReference) async {
    try {
      await _db.collection('jobs').doc(jobId).update({
        'paymentReference': paymentReference,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Payment linked to job: $jobId');
    } catch (e) {
      print('🔥 Error linking payment: $e');
      rethrow;
    }
  }

  // ==========================================
  // 📊 JOB QUERIES
  // ==========================================

  /// Get caregiver's active jobs (in-progress)
  Stream<List<JobModel>> getCaregiverActiveJobs(String caregiverId) {
    return _db
        .collection('jobs')
        .where('caregiverId', isEqualTo: caregiverId)
        .where('status', isEqualTo: 'in-progress')
        .orderBy('startDate', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => JobModel.fromDoc(doc)).toList());
  }

  /// Get caregiver's hired jobs (waiting for acceptance)
  Stream<List<JobModel>> getCaregiverHiredJobs(String caregiverId) {
    return _db
        .collection('jobs')
        .where('caregiverId', isEqualTo: caregiverId)
        .where('status', isEqualTo: 'hired')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => JobModel.fromDoc(doc)).toList());
  }

  /// Get caregiver's completed jobs
  Stream<List<JobModel>> getCaregiverCompletedJobs(String caregiverId) {
    return _db
        .collection('jobs')
        .where('caregiverId', isEqualTo: caregiverId)
        .where('status', isEqualTo: 'completed')
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => JobModel.fromDoc(doc)).toList());
  }

  /// Get client's active posted jobs
  Stream<List<JobModel>> getClientActiveJobs(String clientId) {
    return _db
        .collection('jobs')
        .where('clientId', isEqualTo: clientId)
        .where('status', whereIn: ['open', 'applied', 'hired', 'in-progress'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => JobModel.fromDoc(doc)).toList());
  }

  /// Get client's completed jobs
  Stream<List<JobModel>> getClientCompletedJobs(String clientId) {
    return _db
        .collection('jobs')
        .where('clientId', isEqualTo: clientId)
        .where('status', isEqualTo: 'completed')
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => JobModel.fromDoc(doc)).toList());
  }

  /// Get jobs pending completion confirmation (both parties haven't confirmed)
  Stream<List<JobModel>> getJobsPendingConfirmation(String userId, String userRole) {
    if (userRole == 'caregiver') {
      return _db
          .collection('jobs')
          .where('caregiverId', isEqualTo: userId)
          .where('status', isEqualTo: 'in-progress')
          .where('caregiverConfirmedCompletion', isEqualTo: false)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => JobModel.fromDoc(doc)).toList());
    } else {
      return _db
          .collection('jobs')
          .where('clientId', isEqualTo: userId)
          .where('status', isEqualTo: 'in-progress')
          .where('clientConfirmedCompletion', isEqualTo: false)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => JobModel.fromDoc(doc)).toList());
    }
  }

  // ==========================================
  // 🔍 ADVANCED FILTERING & SEARCH
  // ==========================================

  /// Filter open jobs by budget range
  Stream<List<JobModel>> searchJobsByBudget({
    required num minBudget,
    required num maxBudget,
    required String careType,
  }) {
    return _db
        .collection('jobs')
        .where('status', isEqualTo: 'open')
        .where('budget', isGreaterThanOrEqualTo: minBudget)
        .where('budget', isLessThanOrEqualTo: maxBudget)
        .where('careType', isEqualTo: careType)
        .orderBy('budget', descending: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => JobModel.fromDoc(doc)).toList());
  }

  /// Get all open jobs (for discovery)
  Stream<List<JobModel>> getAllOpenJobs() {
    return _db
        .collection('jobs')
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => JobModel.fromDoc(doc)).toList());
  }

  /// Filter jobs by care type
  Stream<List<JobModel>> getJobsByType(String careType) {
    return _db
        .collection('jobs')
        .where('status', isEqualTo: 'open')
        .where('careType', isEqualTo: careType)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => JobModel.fromDoc(doc)).toList());
  }

  /// Get jobs near user's location (basic distance - requires client-side refinement)
  Future<List<JobModel>> getJobsNearby({
    required String location,
    int limit = 20,
  }) async {
    try {
      final snapshot = await _db
          .collection('jobs')
          .where('status', isEqualTo: 'open')
          .limit(limit)
          .get();

      final jobs = snapshot.docs.map((doc) => JobModel.fromDoc(doc)).toList();
      
      // Filter by location similarity (basic string matching)
      return jobs.where((job) {
        final jobLocation = job.location?.toLowerCase() ?? '';
        final searchLocation = location.toLowerCase();
        return jobLocation.contains(searchLocation) || 
               searchLocation.contains(jobLocation.split(',').first);
      }).toList();
    } catch (e) {
      print('🔥 Error searching jobs nearby: $e');
      rethrow;
    }
  }
}
