import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ========================= USERS =========================
  Future<void> createUser(String uid, Map<String, dynamic> data) async {
    try {
      if (uid.isEmpty) throw Exception("User ID cannot be empty");

      await _db.collection('users').doc(uid).set({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('🔥 Error creating user: $e');
      rethrow;
    }
  }

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

  Future<DocumentSnapshot<Map<String, dynamic>>> getUser(String uid) async {
    try {
      return await _db.collection('users').doc(uid).get();
    } catch (e) {
      print('🔥 Error getting user: $e');
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
      if (title.isEmpty) throw Exception("Job title is required");

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

  Future<DocumentSnapshot<Map<String, dynamic>>> getJob(String jobId) async {
    try {
      return await _db.collection('jobs').doc(jobId).get();
    } catch (e) {
      print('🔥 Error getting job: $e');
      rethrow;
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> jobStream(String jobId) {
    return _db.collection('jobs').doc(jobId).snapshots();
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

  Future<void> updateJob(String jobId, Map<String, dynamic> data) async {
    try {
      if (jobId.isEmpty) throw Exception("Job ID cannot be empty");

      await _db.collection('jobs').doc(jobId).set({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('🔥 Error updating job: $e');
      rethrow;
    }
  }

  Future<void> deleteJob(String jobId) async {
    try {
      if (jobId.isEmpty) throw Exception("Job ID cannot be empty");

      await _db.collection('jobs').doc(jobId).delete();
    } catch (e) {
      print('🔥 Error deleting job: $e');
      rethrow;
    }
  }

  // ========================= APPLICATIONS =========================
  Future<String> createApplication(String jobId, String caregiverId) async {
    try {
      if (jobId.isEmpty || caregiverId.isEmpty) {
        throw Exception("Job ID and Caregiver ID cannot be empty");
      }

      final ref = await _db
          .collection('jobs')
          .doc(jobId)
          .collection('applications')
          .add({
        'jobId': jobId,
        'caregiverId': caregiverId,
        'status': 'applied',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Add caregiver to appliedCaregivers list
      await applyToJob(jobId, caregiverId);

      return ref.id;
    } catch (e) {
      print('🔥 Error creating application: $e');
      rethrow;
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> jobApplicationsStream(
      String jobId) {
    return _db
        .collection('jobs')
        .doc(jobId)
        .collection('applications')
        .orderBy('createdAt', descending: true)
        .snapshots();
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

  // ========================= MESSAGES (Job-based) =========================
  Future<void> sendMessage({
    required String jobId,
    required String senderId,
    required String text,
  }) async {
    try {
      if (jobId.isEmpty || senderId.isEmpty) {
        throw Exception("Job ID and Sender ID cannot be empty");
      }
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

  Stream<QuerySnapshot<Map<String, dynamic>>> messagesStream(String jobId) {
    return _db
        .collection('jobs')
        .doc(jobId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // ========================= CONVERSATIONS =========================
  Future<String> createConversation({
    required List<String> participantIds,
    required List<String> participantNames,
  }) async {
    try {
      if (participantIds.length < 2) {
        throw Exception("At least 2 participants are required");
      }
      if (participantIds.length != participantNames.length) {
        throw Exception("Participant IDs and names must match in length");
      }

      participantIds.sort(); // Ensure consistent ordering

      final ref = await _db.collection('conversations').add({
        'participantIds': participantIds,
        'participantNames': participantNames,
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': {
          for (var id in participantIds) id: 0,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    } catch (e) {
      print('🔥 Error creating conversation: $e');
      rethrow;
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> conversationsStream(String uid) {
    return _db
        .collection('conversations')
        .where('participantIds', arrayContains: uid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getConversation(
      String conversationId) async {
    try {
      return await _db.collection('conversations').doc(conversationId).get();
    } catch (e) {
      print('🔥 Error getting conversation: $e');
      rethrow;
    }
  }

  Future<void> sendConversationMessage({
    required String conversationId,
    required String senderId,
    required String text,
  }) async {
    try {
      if (conversationId.isEmpty || senderId.isEmpty) {
        throw Exception("Conversation ID and Sender ID cannot be empty");
      }
      if (text.trim().isEmpty) throw Exception("Message cannot be empty");

      final conversationRef =
          _db.collection('conversations').doc(conversationId);

      await _db.runTransaction((txn) async {
        // Add message to subcollection
        await txn.set(
          conversationRef.collection('messages').doc(),
          {
            'senderId': senderId,
            'text': text,
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
          },
        );

        // Update conversation metadata
        await txn.update(conversationRef, {
          'lastMessage': text,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      print('🔥 Error sending conversation message: $e');
      rethrow;
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> conversationMessagesStream(
      String conversationId) {
    return _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  Future<void> markConversationAsRead(
      String conversationId, String userId) async {
    try {
      if (conversationId.isEmpty || userId.isEmpty) {
        throw Exception("Conversation ID and User ID cannot be empty");
      }

      await _db.collection('conversations').doc(conversationId).update({
        'unreadCount.$userId': 0,
      });
    } catch (e) {
      print('🔥 Error marking conversation as read: $e');
      rethrow;
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    try {
      if (conversationId.isEmpty) {
        throw Exception("Conversation ID cannot be empty");
      }

      await _db.collection('conversations').doc(conversationId).delete();
    } catch (e) {
      print('🔥 Error deleting conversation: $e');
      rethrow;
    }
  }

  // ========================= VISITS =========================
  Future<String> createVisit({
    required String clientId,
    required String caregiverId,
    required DateTime dateTime,
    required String serviceType,
    String? location,
    String? notes,
  }) async {
    try {
      if (clientId.isEmpty || caregiverId.isEmpty) {
        throw Exception("Client ID and Caregiver ID are required");
      }

      final ref = await _db
          .collection('users')
          .doc(clientId)
          .collection('visits')
          .add({
        'clientId': clientId,
        'caregiverId': caregiverId,
        'dateTime': Timestamp.fromDate(dateTime),
        'serviceType': serviceType,
        'location': location,
        'notes': notes,
        'status': 'upcoming',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    } catch (e) {
      print('🔥 Error creating visit: $e');
      rethrow;
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> visitsStream(String clientId) {
    return _db
        .collection('users')
        .doc(clientId)
        .collection('visits')
        .orderBy('dateTime', descending: true)
        .snapshots();
  }

  Future<void> updateVisitStatus(
      String clientId, String visitId, String status) async {
    try {
      if (clientId.isEmpty || visitId.isEmpty) {
        throw Exception("Client ID and Visit ID cannot be empty");
      }

      await _db
          .collection('users')
          .doc(clientId)
          .collection('visits')
          .doc(visitId)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('🔥 Error updating visit status: $e');
      rethrow;
    }
  }

  Future<void> deleteVisit(String clientId, String visitId) async {
    try {
      if (clientId.isEmpty || visitId.isEmpty) {
        throw Exception("Client ID and Visit ID cannot be empty");
      }

      await _db
          .collection('users')
          .doc(clientId)
          .collection('visits')
          .doc(visitId)
          .delete();
    } catch (e) {
      print('🔥 Error deleting visit: $e');
      rethrow;
    }
  }

  // ========================= PAYMENTS =========================
  Future<String> createPayment({
    required String clientId,
    required String caregiverId,
    required num amount,
    required String description,
    String type = "client_payment",
    num? carelinkFee,
    num? caregiverCommission,
    String? reference,
  }) async {
    try {
      if (clientId.isEmpty || caregiverId.isEmpty) {
        throw Exception("Client ID and Caregiver ID are required");
      }
      if (amount <= 0) throw Exception("Amount must be greater than 0");

      final ref = await _db
          .collection('users')
          .doc(clientId)
          .collection('payments')
          .add({
        'clientId': clientId,
        'caregiverId': caregiverId,
        'amount': amount,
        'carelinkFee': carelinkFee ?? 0,
        'caregiverCommission': caregiverCommission ?? 0,
        'description': description,
        'type': type,
        'reference': reference ?? 'carelink_${DateTime.now().millisecondsSinceEpoch}',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    } catch (e) {
      print('🔥 Error creating payment: $e');
      rethrow;
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> paymentsStream(String clientId) {
    return _db
        .collection('users')
        .doc(clientId)
        .collection('payments')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> updatePaymentStatus(
      String clientId, String paymentId, String status) async {
    try {
      if (clientId.isEmpty || paymentId.isEmpty) {
        throw Exception("Client ID and Payment ID cannot be empty");
      }

      await _db
          .collection('users')
          .doc(clientId)
          .collection('payments')
          .doc(paymentId)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('🔥 Error updating payment status: $e');
      rethrow;
    }
  }

  Future<void> deletePayment(String clientId, String paymentId) async {
    try {
      if (clientId.isEmpty || paymentId.isEmpty) {
        throw Exception("Client ID and Payment ID cannot be empty");
      }

      await _db
          .collection('users')
          .doc(clientId)
          .collection('payments')
          .doc(paymentId)
          .delete();
    } catch (e) {
      print('🔥 Error deleting payment: $e');
      rethrow;
    }
  }

  // ========================= PREMIUM SUBSCRIPTIONS =========================
  Future<void> activatePremium(String caregiverId) async {
    try {
      if (caregiverId.isEmpty) throw Exception("Caregiver ID cannot be empty");

      await _db.collection('users').doc(caregiverId).set({
        'isPremium': true,
        'premiumActivatedAt': FieldValue.serverTimestamp(),
        'premiumExpiresAt':
            Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
      }, SetOptions(merge: true));

      print('⭐ Premium activated for caregiver: $caregiverId');
    } catch (e) {
      print('🔥 Error activating premium: $e');
      rethrow;
    }
  }

  Future<void> deactivatePremium(String caregiverId) async {
    try {
      if (caregiverId.isEmpty) throw Exception("Caregiver ID cannot be empty");

      await _db.collection('users').doc(caregiverId).set({
        'isPremium': false,
      }, SetOptions(merge: true));

      print('⭐ Premium deactivated for caregiver: $caregiverId');
    } catch (e) {
      print('🔥 Error deactivating premium: $e');
      rethrow;
    }
  }
}