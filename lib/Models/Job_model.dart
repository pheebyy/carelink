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
  final String status; // open | applied | hired
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final List<String> appliedCaregivers;

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
    this.appliedCaregivers = const [],
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
      appliedCaregivers: (data['appliedCaregivers'] as List?)?.map((e) => e.toString()).toList() ?? [],
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
    };
  }
}
