import 'package:cloud_firestore/cloud_firestore.dart';

class JobAnalytics {
  final String userId;
  final int totalJobsCompleted;
  final int totalJobsAccepted;
  final double completionRate; // Percentage of jobs completed
  final double averageRating; // 1-5 stars
  final int totalReviews;
  final double totalEarnings; // Total money earned (KES)
  final int currentlyAcceptedJobs;
  final Timestamp lastUpdated;

  JobAnalytics({
    required this.userId,
    required this.totalJobsCompleted,
    required this.totalJobsAccepted,
    required this.completionRate,
    required this.averageRating,
    required this.totalReviews,
    required this.totalEarnings,
    required this.currentlyAcceptedJobs,
    required this.lastUpdated,
  });

  factory JobAnalytics.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JobAnalytics(
      userId: doc.id,
      totalJobsCompleted: data['totalJobsCompleted'] as int? ?? 0,
      totalJobsAccepted: data['totalJobsAccepted'] as int? ?? 0,
      completionRate: (data['completionRate'] as num?)?.toDouble() ?? 0.0,
      averageRating: (data['averageRating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: data['totalReviews'] as int? ?? 0,
      totalEarnings: (data['totalEarnings'] as num?)?.toDouble() ?? 0.0,
      currentlyAcceptedJobs: data['currentlyAcceptedJobs'] as int? ?? 0,
      lastUpdated: data['lastUpdated'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalJobsCompleted': totalJobsCompleted,
      'totalJobsAccepted': totalJobsAccepted,
      'completionRate': completionRate,
      'averageRating': averageRating,
      'totalReviews': totalReviews,
      'totalEarnings': totalEarnings,
      'currentlyAcceptedJobs': currentlyAcceptedJobs,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

  // Get quality tier based on rating and reviews
  String getQualityTier() {
    if (totalReviews < 5) return 'New';
    if (averageRating >= 4.8) return 'Excellent';
    if (averageRating >= 4.5) return 'Very Good';
    if (averageRating >= 4.0) return 'Good';
    return 'Fair';
  }

  // Format earnings for display
  String getFormattedEarnings() {
    return 'KES ${totalEarnings.toStringAsFixed(0)}';
  }

  // Get completion rate as percentage string
  String getCompletionRateString() {
    return '${(completionRate * 100).toStringAsFixed(0)}%';
  }
}
