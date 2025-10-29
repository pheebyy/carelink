import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ========================= USERS =========================
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      if (uid.isEmpty) throw Exception("User ID cannot be empty");

      await _db.collection('users').doc(uid).set({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('🔥 Error updating user: $e');
      rethrow;
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> userStream(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  // ========================= JOBS =========================
  Future<String> createJob({
    required String clientId,
    required String title,
    required String description,
    required String careType,
    String? location,
    num? budget,
  }) async {
    try {
      if (clientId.isEmpty) throw Exception("Client ID is required");

      final ref = await _db.collection('jobs').add({
        'clientId': clientId,
        'caregiverId': null,
        'title': title,
        'description': description,
        'careType': careType,
        'location': location,
        'budget': budget,
        'status': 'open',
        'appliedCaregivers': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    } catch (e) {
      print('🔥 Error creating job: $e');
      rethrow;
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> openJobsStream() {
    return _db
        .collection('jobs')
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> clientJobsStream(String clientId) {
    return _db
        .collection('jobs')
        .where('clientId', isEqualTo: clientId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> applyToJob(String jobId, String caregiverId) async {
    try {
      if (jobId.isEmpty || caregiverId.isEmpty) {
        throw Exception("Job ID and Caregiver ID cannot be empty");
      }

      final jobRef = _db.collection('jobs').doc(jobId);

      await _db.runTransaction((txn) async {
        final snap = await txn.get(jobRef);
        if (!snap.exists) throw Exception('Job not found');

        final data = snap.data() ?? {};
        final List<dynamic> applied = (data['appliedCaregivers'] as List?) ?? [];

        if (!applied.contains(caregiverId)) {
          applied.add(caregiverId);
          txn.update(jobRef, {
            'appliedCaregivers': applied,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      print('🔥 Error applying to job: $e');
      rethrow;
    }
  }

  Future<void> hireCaregiver(String jobId, String caregiverId) async {
    try {
      if (jobId.isEmpty || caregiverId.isEmpty) {
        throw Exception("Job ID and Caregiver ID cannot be empty");
      }

      await _db.collection('jobs').doc(jobId).update({
        'caregiverId': caregiverId,
        'status': 'hired',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('🔥 Error hiring caregiver: $e');
      rethrow;
    }
  }

  // ========================= APPLICATIONS =========================
  Future<void> createApplication(String jobId, String caregiverId) async {
    try {
      await _db.collection('jobs').doc(jobId).collection('applications').add({
        'jobId': jobId,
        'caregiverId': caregiverId,
        'status': 'applied',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('🔥 Error creating application: $e');
      rethrow;
    }
  }

  Future<void> updateApplicationStatus(
      String jobId, String applicationId, String status) async {
    try {
      await _db
          .collection('jobs')
          .doc(jobId)
          .collection('applications')
          .doc(applicationId)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('🔥 Error updating application: $e');
      rethrow;
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> jobStream(String jobId) {
    return _db.collection('jobs').doc(jobId).snapshots();
  }

  // ========================= MESSAGES =========================
  Stream<QuerySnapshot<Map<String, dynamic>>> messagesStream(String jobId) {
    return _db
        .collection('jobs')
        .doc(jobId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  Future<void> sendMessage({
    required String jobId,
    required String senderId,
    required String text,
  }) async {
    try {
      if (text.trim().isEmpty) throw Exception("Message cannot be empty");

      await _db.collection('jobs').doc(jobId).collection('messages').add({
        'senderId': senderId,
        'text': text,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('🔥 Error sending message: $e');
      rethrow;
    }
  }
}
