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
      print('📤 Starting verification document upload for: $documentType');
      
      if (bytes.isEmpty) {
        throw Exception('File is empty - unable to upload');
      }
      
      final fileSizeMB = bytes.length / (1024 * 1024);
      print('📊 File size: ${fileSizeMB.toStringAsFixed(2)} MB');
      
      if (bytes.length > 5 * 1024 * 1024) {
        throw Exception('File size exceeds 5MB limit (current: ${fileSizeMB.toStringAsFixed(2)} MB)');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${documentType}_$timestamp.$fileExtension';
      final storagePath = 'users/$uid/verification/$fileName';
      final ref = _storage.ref().child(storagePath);
      final metadata = SettableMetadata(contentType: contentType);

      print('📁 Uploading to path: $storagePath');
      print('🔐 User UID: $uid');
      print('📝 Content Type: $contentType');

      final snap = await ref.putData(Uint8List.fromList(bytes), metadata);
      final url = await snap.ref.getDownloadURL();

      print('✅ Upload successful! Download URL: $url');
      return {
        'storageUrl': url,
        'fileName': fileName,
      };
    } on FirebaseException catch (e) {
      print('🔴 Firebase error - Code: ${e.code}, Message: ${e.message}');
      String userMessage = '';
      
      switch (e.code) {
        case 'permission-denied':
          userMessage = 'Permission denied. Please ensure you are signed in and try again.';
          break;
        case 'quota-exceeded':
          userMessage = 'Storage quota exceeded. Please contact support.';
          break;
        case 'invalid-argument':
          userMessage = 'Invalid file format or metadata.';
          break;
        default:
          userMessage = e.message ?? 'Upload failed - please try again';
      }
      
      throw Exception('Upload failed: $userMessage');
    } catch (e) {
      print('🔴 General error: $e');
      throw Exception('Unexpected error during upload: ${e.toString()}');
    }
  }
}
