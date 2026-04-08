import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String userId; // Who receives the notification
  final String type; // 'job_hired', 'job_completed', 'review_submitted', 'job_accepted'
  final String title;
  final String message;
  final String? jobId; // Related job (if applicable)
  final String? relatedUserId; // Who triggered the notification (if applicable)
  final bool isRead;
  final Timestamp createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
    this.jobId,
    this.relatedUserId,
  });

  factory NotificationModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      type: data['type'] as String? ?? '',
      title: data['title'] as String? ?? '',
      message: data['message'] as String? ?? '',
      jobId: data['jobId'] as String?,
      relatedUserId: data['relatedUserId'] as String?,
      isRead: data['isRead'] as bool? ?? false,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type,
      'title': title,
      'message': message,
      'jobId': jobId,
      'relatedUserId': relatedUserId,
      'isRead': isRead,
      'createdAt': createdAt,
    };
  }

  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id: id,
      userId: userId,
      type: type,
      title: title,
      message: message,
      jobId: jobId,
      relatedUserId: relatedUserId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}
