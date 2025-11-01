import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> login(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> logout() async => _auth.signOut();

  Future<UserCredential> signup({
    required String email,
    required String password,
    required String role, // 'caregiver' | 'client'
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);

    await _firestore.collection('users').doc(cred.user!.uid).set({
      'email': email,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return cred;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> getUserDoc([String? uid]) async {
    final id = uid ?? _auth.currentUser?.uid;
    if (id == null) return null;
    return _firestore.collection('users').doc(id).get();
  }
}
