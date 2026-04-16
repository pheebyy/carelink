import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';



class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadProfilePhoto({
    required String uid,
    required List<int> bytes,
    String contentType = 'image/jpeg',
  }) async {
    try {
      final ref = _storage.ref().child('users/$uid/profile.jpg');
      final metadata = SettableMetadata(contentType: contentType);

      final snap = await ref.putData(Uint8List.fromList(bytes), metadata);
      final url = await snap.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'profilePhotoUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return url;
    } on FirebaseException catch (e) {
      throw Exception('Storage upload failed (${e.code}): ${e.message ?? 'Unknown error'}');
    }
  }

  /// Upload verification document (license, national ID, passport)
  /// Returns map with storageUrl and fileName
  Future<Map<String, String>> uploadVerificationDocument({
    required String uid,
    required String documentType, // 'practice_license' | 'national_id' | 'passport_photo'
    required List<int> bytes,
    required String fileExtension, // 'jpg', 'png', 'pdf'
    String contentType = 'image/jpeg',
  }) async {
    try {
      if (bytes.length > 5 * 1024 * 1024) {
        throw Exception('File size exceeds 5MB limit');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${documentType}_$timestamp.$fileExtension';
      final ref = _storage.ref().child('users/$uid/verification/$fileName');
      final metadata = SettableMetadata(contentType: contentType);

      final snap = await ref.putData(Uint8List.fromList(bytes), metadata);
      final url = await snap.ref.getDownloadURL();

      return {
        'storageUrl': url,
        'fileName': fileName,
      };
    } on FirebaseException catch (e) {
      throw Exception('Verification document upload failed (${e.code}): ${e.message ?? 'Unknown error'}');
    }
  }
}
