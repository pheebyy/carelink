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
    final ref = _storage.ref().child('users/$uid/profile.jpg');
    SettableMetadata metadata = SettableMetadata(contentType: contentType);

    UploadTask uploadTask;
    uploadTask = ref.putData(Uint8List.fromList(bytes), metadata);

    final snap = await uploadTask;
    final url = await snap.ref.getDownloadURL();

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'profilePhotoUrl': url,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return url;
  }
}
