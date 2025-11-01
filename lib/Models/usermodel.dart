import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
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
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  AppUser({
    required this.uid,
    required this.email,
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
    this.createdAt,
    this.updatedAt,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      email: data['email'] ?? '',
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
      createdAt: data['createdAt'],
      updatedAt: data['updatedAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
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
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
