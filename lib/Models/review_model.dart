import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a review/rating for a completed job
class ReviewModel {
  final String id;
  final String jobId;
  final String reviewerId; // Who wrote the review (client or caregiver)
  final String revieweeId; // Who is being reviewed
  final String reviewerRole; // 'client' or 'caregiver'
  final double rating; // 1-5 stars
  final String comment;
  final Timestamp createdAt;
  final bool isFlagged; // For dispute/report functionality
  final String? flagReason;

  ReviewModel({
    required this.id,
    required this.jobId,
    required this.reviewerId,
    required this.revieweeId,
    required this.reviewerRole,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.isFlagged = false,
    this.flagReason,
  });

  /// Convert to Firestore document
  Map<String, dynamic> toMap() => {
    'jobId': jobId,
    'reviewerId': reviewerId,
    'revieweeId': revieweeId,
    'reviewerRole': reviewerRole,
    'rating': rating,
    'comment': comment,
    'createdAt': createdAt,
    'isFlagged': isFlagged,
    'flagReason': flagReason,
  };

  /// Create from Firestore document
  factory ReviewModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReviewModel(
      id: doc.id,
      jobId: data['jobId'] ?? '',
      reviewerId: data['reviewerId'] ?? '',
      revieweeId: data['revieweeId'] ?? '',
      reviewerRole: data['reviewerRole'] ?? 'client',
      rating: (data['rating'] ?? 0).toDouble(),
      comment: data['comment'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      isFlagged: data['isFlagged'] ?? false,
      flagReason: data['flagReason'],
    );
  }
}

/// Represents aggregated ratings for a user
class UserRatings {
  final String userId;
  final double averageRating; // Weighted average (1-5)
  final int totalReviews;
  final Map<int, int> ratingDistribution; // {5: 10, 4: 5, ...}
  final List<ReviewModel> recentReviews; // Last 10 reviews

  UserRatings({
    required this.userId,
    required this.averageRating,
    required this.totalReviews,
    required this.ratingDistribution,
    required this.recentReviews,
  });

  /// Calculate if user meets quality threshold (4.0+ stars)
  bool meetsQualityThreshold() => averageRating >= 4.0;

  /// Get star rating text (e.g., "4.5 ⭐")
  String getDisplayRating() => '${averageRating.toStringAsFixed(1)} ⭐';
}
