import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // USERS
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).set({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> userStream(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  // JOBS
  Future<String> createJob({
    required String clientId,
    required String title,
    required String description,
    required String careType,
    String? location,
    num? budget,
  }) async {
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
    final jobRef = _db.collection('jobs').doc(jobId);
    await _db.runTransaction((txn) async {
      final snap = await txn.get(jobRef);
      if (!snap.exists) {
        throw Exception('Job not found');
      }
      final data = snap.data() as Map<String, dynamic>;
      final List<dynamic> applied = (data['appliedCaregivers'] as List?) ?? [];
      if (!applied.contains(caregiverId)) {
        applied.add(caregiverId);
        txn.update(jobRef, {
          'appliedCaregivers': applied,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> hireCaregiver(String jobId, String caregiverId) async {
    await _db.collection('jobs').doc(jobId).update({
      'caregiverId': caregiverId,
      'status': 'hired',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> createApplication(String jobId, String caregiverId) async {
    await _db.collection('jobs').doc(jobId).collection('applications').add({
      'jobId': jobId,
      'caregiverId': caregiverId,
      'status': 'applied',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateApplicationStatus(String jobId, String applicationId, String status) async {
    await _db.collection('jobs').doc(jobId).collection('applications').doc(applicationId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> jobStream(String jobId) {
    return _db.collection('jobs').doc(jobId).snapshots();
  }

  // MESSAGES under jobs/{jobId}/messages
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
    await _db.collection('jobs').doc(jobId).collection('messages').add({
      'senderId': senderId,
      'text': text,
      'read': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
