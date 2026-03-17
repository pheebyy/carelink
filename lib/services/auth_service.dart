import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:carelink/services/location_tracking_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> login(String email, String password) async {
    final credential =
        await _auth.signInWithEmailAndPassword(email: email, password: password);

    final uid = credential.user?.uid;
    if (uid != null) {
      await _startTrackingIfEnabled(uid);
    }

    return credential;
  }

  Future<void> logout() async {
    await LocationTrackingService.instance.stopTracking();
    await _auth.signOut();
  }

  Future<UserCredential> signup({
    required String email,
    required String password,
    required String role, // 'caregiver' | 'client'
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);

    await _firestore.collection('users').doc(cred.user!.uid).set({
      'email': email,
      'role': role,
      'gpsTrackingEnabled': false,
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

  Future<void> _startTrackingIfEnabled(String uid) async {
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final data = userDoc.data() ?? <String, dynamic>{};
    final enabled = data['gpsTrackingEnabled'] == true;
    if (enabled) {
      await LocationTrackingService.instance.startTracking(uid);
    }
  }
}
