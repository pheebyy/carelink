import 'package:cloud_firestore/cloud_firestore.dart';

class VerificationDocument {
  final String documentType; // 'practice_license' | 'national_id' | 'passport_photo'
  final String fileName;
  final String storageUrl;
  final Timestamp uploadedAt;
  final String documentValue; // license #, ID number, passport number
  final String status; // 'submitted' | 'approved' | 'rejected'
  final String? verifiedAgainst; // 'KNC Registry', 'National ID Database', etc.
  final String? verificationNotes;
  final Timestamp? verificationDate;
  final String? verificationMethod; // 'manual_board_lookup'
  final Timestamp? expiryDate; // when the document expires
  final bool expiryReminderSent; // track if reminder was sent
  final Timestamp? lastReminderDate; // when the last reminder was sent

  VerificationDocument({
    required this.documentType,
    required this.fileName,
    required this.storageUrl,
    required this.uploadedAt,
    required this.documentValue,
    required this.status,
    this.verifiedAgainst,
    this.verificationNotes,
    this.verificationDate,
    this.verificationMethod,
    this.expiryDate,
    this.expiryReminderSent = false,
    this.lastReminderDate,
  });

  factory VerificationDocument.fromMap(Map<String, dynamic> data) {
    return VerificationDocument(
      documentType: data['documentType'] ?? '',
      fileName: data['fileName'] ?? '',
      storageUrl: data['storageUrl'] ?? '',
      uploadedAt: data['uploadedAt'] ?? Timestamp.now(),
      documentValue: data['documentValue'] ?? '',
      status: data['status'] ?? 'submitted',
      verifiedAgainst: data['verifiedAgainst'],
      verificationNotes: data['verificationNotes'],
      verificationDate: data['verificationDate'],
      verificationMethod: data['verificationMethod'],
      expiryDate: data['expiryDate'],
      expiryReminderSent: data['expiryReminderSent'] ?? false,
      lastReminderDate: data['lastReminderDate'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'documentType': documentType,
      'fileName': fileName,
      'storageUrl': storageUrl,
      'uploadedAt': uploadedAt,
      'documentValue': documentValue,
      'status': status,
      'verifiedAgainst': verifiedAgainst,
      'verificationNotes': verificationNotes,
      'verificationDate': verificationDate,
      'verificationMethod': verificationMethod,
      'expiryDate': expiryDate,
      'expiryReminderSent': expiryReminderSent,
      'lastReminderDate': lastReminderDate,
    };
  }
}

class AppUser {
  final String uid;
  final String email;
  final String? phone;
  final String role; // 'caregiver' | 'client'
  final String? name;
  final int? age;
  final String? gender;
  final int? experienceYears;
  final List<String>? specializations;
  final String? availability; // simple text for MVP
  final String? location;
  final String? profilePhotoUrl;
  final double? rating;
  final String? verificationStatus; // 'pending' | 'approved' | 'rejected'
  final List<VerificationDocument>? verificationDocuments;
  final Timestamp? verificationSubmittedAt;
  final Timestamp? verificationApprovedAt;
  final String? verificationApprovedBy; // admin UID
  final String? overallVerificationNotes;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  AppUser({
    required this.uid,
    required this.email,
    this.phone,
    required this.role,
    this.name,
    this.age,
    this.gender,
    this.experienceYears,
    this.specializations,
    this.availability,
    this.location,
    this.profilePhotoUrl,
    this.rating,
    this.verificationStatus,
    this.verificationDocuments,
    this.verificationSubmittedAt,
    this.verificationApprovedAt,
    this.verificationApprovedBy,
    this.overallVerificationNotes,
    this.createdAt,
    this.updatedAt,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      email: data['email'] ?? '',
      phone: data['phone'],
      role: data['role'] ?? 'client',
      name: data['name'],
      age: data['age'],
      gender: data['gender'],
      experienceYears: data['experienceYears'],
      specializations: (data['specializations'] as List?)?.map((e) => e.toString()).toList(),
      availability: data['availability'],
      location: data['location'],
      profilePhotoUrl: data['profilePhotoUrl'],
      rating: (data['rating'] is int) ? (data['rating'] as int).toDouble() : data['rating'],
      verificationStatus: data['verificationStatus'],
      verificationDocuments: (data['verificationDocuments'] as List?)
          ?.map((doc) => VerificationDocument.fromMap(doc as Map<String, dynamic>))
          .toList(),
      verificationSubmittedAt: data['verificationSubmittedAt'],
      verificationApprovedAt: data['verificationApprovedAt'],
      verificationApprovedBy: data['verificationApprovedBy'],
      overallVerificationNotes: data['overallVerificationNotes'],
      createdAt: data['createdAt'],
      updatedAt: data['updatedAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'phone': phone,
      'role': role,
      'name': name,
      'age': age,
      'gender': gender,
      'experienceYears': experienceYears,
      'specializations': specializations,
      'availability': availability,
      'location': location,
      'profilePhotoUrl': profilePhotoUrl,
      'rating': rating,
      'verificationStatus': verificationStatus,
      'verificationDocuments': verificationDocuments?.map((doc) => doc.toMap()).toList(),
      'verificationSubmittedAt': verificationSubmittedAt,
      'verificationApprovedAt': verificationApprovedAt,
      'verificationApprovedBy': verificationApprovedBy,
      'overallVerificationNotes': overallVerificationNotes,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
