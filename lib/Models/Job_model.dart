import 'package:cloud_firestore/cloud_firestore.dart';

class JobModel {
  final String id;
  final String clientId;
  final String? caregiverId;
  final String title;
  final String description;
  final String careType; // full-time | part-time | overnight
  final String? location;
  final num? budget;
  final String status; // open | applied | hired | in-progress | completed | canceled
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final Timestamp? startDate;
  final Timestamp? endDate;
  final Timestamp? completedAt;
  final Timestamp? canceledAt;
  final List<String> appliedCaregivers;
  final bool caregiverAccepted; // Did caregiver accept the job?
  final bool clientConfirmedCompletion;
  final bool caregiverConfirmedCompletion;
  final String? paymentReference; // Link to payment transaction
  final bool hasPendingBids; // ✅ NEW: Indicates if job has pending bids

  JobModel({
    required this.id,
    required this.clientId,
    required this.title,
    required this.description,
    required this.careType,
    required this.status,
    this.caregiverId,
    this.location,
    this.budget,
    this.createdAt,
    this.updatedAt,
    this.startDate,
    this.endDate,
    this.completedAt,
    this.canceledAt,
    this.appliedCaregivers = const [],
    this.caregiverAccepted = false,
    this.clientConfirmedCompletion = false,
    this.caregiverConfirmedCompletion = false,
    this.paymentReference,
    this.hasPendingBids = false, // ✅ NEW
  });

  factory JobModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JobModel(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      caregiverId: data['caregiverId'],
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      careType: data['careType'] ?? 'part-time',
      location: data['location'],
      budget: data['budget'],
      status: data['status'] ?? 'open',
      createdAt: data['createdAt'],
      updatedAt: data['updatedAt'],
      startDate: data['startDate'],
      endDate: data['endDate'],
      completedAt: data['completedAt'],
      canceledAt: data['canceledAt'],
      appliedCaregivers: (data['appliedCaregivers'] as List?)?.map((e) => e.toString()).toList() ?? [],
      caregiverAccepted: data['caregiverAccepted'] ?? false,
      clientConfirmedCompletion: data['clientConfirmedCompletion'] ?? false,
      caregiverConfirmedCompletion: data['caregiverConfirmedCompletion'] ?? false,
      paymentReference: data['paymentReference'],
      hasPendingBids: data['hasPendingBids'] ?? false, // ✅ NEW
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'caregiverId': caregiverId,
      'title': title,
      'description': description,
      'careType': careType,
      'location': location,
      'budget': budget,
      'status': status,
      'appliedCaregivers': appliedCaregivers,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'startDate': startDate,
      'endDate': endDate,
      'completedAt': completedAt,
      'canceledAt': canceledAt,
      'caregiverAccepted': caregiverAccepted,
      'clientConfirmedCompletion': clientConfirmedCompletion,
      'caregiverConfirmedCompletion': caregiverConfirmedCompletion,
      'paymentReference': paymentReference,
    };
  }
}
