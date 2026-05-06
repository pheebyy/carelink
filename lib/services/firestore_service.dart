import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

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
      print('Error creating user: $e');
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
      print('Error updating user: $e');
      rethrow;
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUser(String uid) async {
    try {
      return await _db.collection('users').doc(uid).get();
    } catch (e) {
      print('Error getting user: $e');
      rethrow;
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> userStream(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  // ========================= VERIFICATION =========================
  /// Submits verification documents for caregiver
  /// documents: List of maps with: {documentType, storageUrl, fileName, documentValue, expiryDate?}
  Future<void> submitVerificationDocuments({
    required String caregiverId,
    required List<Map<String, dynamic>> documents,
  }) async {
    try {
      if (caregiverId.isEmpty) throw Exception("Caregiver ID is required");
      if (documents.isEmpty) throw Exception("At least one document is required");
      if (documents.length > 3) throw Exception("Maximum 3 documents allowed");

      // Convert documents to VerificationDocument format
      final verificationDocuments = documents
          .map((doc) => {
                'documentType': doc['documentType'] ?? '',
                'fileName': doc['fileName'] ?? '',
                'storageUrl': doc['storageUrl'] ?? '',
                'uploadedAt': FieldValue.serverTimestamp(),
                'documentValue': doc['documentValue'] ?? '',
                'status': 'submitted',
                'expiryDate': doc['expiryDate'], // Add expiry date if provided
              })
          .toList();

      await _db.collection('users').doc(caregiverId).update({
        'verificationDocuments': FieldValue.arrayUnion(verificationDocuments),
        'verificationStatus': 'pending',
        'verificationSubmittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('Verification documents submitted for caregiver: $caregiverId');

      // Send verification submission email
      await _sendVerificationSubmissionEmail(caregiverId);
    } catch (e) {
      print('Error submitting verification documents: $e');
      rethrow;
    }
  }

  /// Send verification submission confirmation email to caregiver
  Future<void> _sendVerificationSubmissionEmail(String caregiverId) async {
    try {
      // Get caregiver info
      final userDoc = await _db.collection('users').doc(caregiverId).get();
      if (!userDoc.exists) {
        print('Caregiver document not found for email');
        return;
      }

      final userData = userDoc.data() ?? {};
      final caregiverEmail = userData['email'] as String? ?? '';
      final caregiverName = userData['name'] as String? ?? userData['displayName'] ?? 'Caregiver';

      if (caregiverEmail.isEmpty) {
        print('Caregiver email not found');
        return;
      }

      // Call Cloud Function to send email
      print('📧 Calling sendVerificationSubmissionEmail Cloud Function...');
      final result = await _functions.httpsCallable('sendVerificationSubmissionEmail').call({
        'caregiverId': caregiverId,
        'caregiverEmail': caregiverEmail,
        'caregiverName': caregiverName,
      });

      if (result.data['success']) {
        print('Verification submission email sent successfully');
      } else {
        print('Email could not be sent (SendGrid may not be configured)');
      }
    } catch (e) {
      print('Error sending verification submission email: $e');
      // Don't rethrow - email sending is not critical to the verification flow
    }
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
      print(' Error creating job: $e');
      rethrow;
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getJob(String jobId) async {
    try {
      return await _db.collection('jobs').doc(jobId).get();
    } catch (e) {
      print('Error getting job: $e');
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
      print('Error updating job: $e');
      rethrow;
    }
  }

  Future<void> deleteJob(String jobId) async {
    try {
      if (jobId.isEmpty) throw Exception("Job ID cannot be empty");

      await _db.collection('jobs').doc(jobId).delete();
    } catch (e) {
      print('Error deleting job: $e');
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
      print(' Error creating application: $e');
      rethrow;
    }
  }

  // ========================= BIDS =========================
  Future<String> createBid({
    required String jobId,
    required String caregiverId,
    required double amount,
    required String proposal,
    int? estimatedDuration, // in hours
  }) async {
    try {
      print('\n ===== BID CREATION STARTED =====');
      print('   JobID: $jobId');
      print('   CaregiverID: $caregiverId');
      print('   Amount: $amount');
      final proposalPreview = proposal.length > 50 ? proposal.substring(0, 50) : proposal;
      print('   Proposal: $proposalPreview...');
      print('   Duration: $estimatedDuration hours\n');
      
      // Validate inputs
      if (jobId.isEmpty || caregiverId.isEmpty) {
        throw Exception("Job ID and Caregiver ID cannot be empty");
      }
      if (amount <= 0) {
        throw Exception("Bid amount must be greater than 0");
      }

      print(' Input validation passed');

      //  VERIFICATION GATE: Check if caregiver is verified
      print(' Checking caregiver verification status...');
      final caregiverSnap = await _db.collection('users').doc(caregiverId).get();
      if (!caregiverSnap.exists) {
        throw Exception("Caregiver not found in users collection");
      }
      
      final caregiverData = caregiverSnap.data() ?? <String, dynamic>{};
      final verificationStatus = caregiverData['verificationStatus'] ?? 'not-started';
      print('   Verification Status: $verificationStatus');
      
      // Allow 'approved' OR auto-approve if they have submitted documents
      final hasSubmittedDocuments = (caregiverData['verificationDocuments'] as List?)?.isNotEmpty ?? false;
      final isVerified = verificationStatus == 'approved';
      final hasDocuments = hasSubmittedDocuments || isVerified;
      
      if (!hasDocuments && verificationStatus != 'approved') {
        throw Exception(' You must complete verification to bid on jobs. Status: $verificationStatus. Please submit your verification documents.');
      }
      
      if (verificationStatus == 'pending') {
        print('  Verification pending - but allowing bid since documents submitted');
      }
      
      print(' Caregiver verified (or documents submitted)');

      final jobRef = _db.collection('jobs').doc(jobId);
      // Enforce one bid per caregiver by using caregiverId as bid document id.
      final bidRef = jobRef.collection('bids').doc(caregiverId);

      //  Fetch job data and caregiver name for notification
      final jobDoc = await jobRef.get();
      if (!jobDoc.exists) {
        throw Exception(" Job not found");
      }
      final jobData = jobDoc.data() ?? <String, dynamic>{};
      final jobTitle = jobData['title'] ?? 'Job';
      final clientId = jobData['clientId'] ?? '';
      final caregiverName = caregiverData['fullName'] ?? caregiverData['name'] ?? 'A caregiver';

      print(' Starting transaction...');
      await _db.runTransaction((txn) async {
        final jobSnap = await txn.get(jobRef);
        if (!jobSnap.exists) {
          throw Exception(" Job not found");
        }
        print(' Job found');

        final jobData = jobSnap.data() ?? <String, dynamic>{};
        final jobStatus = (jobData['status'] ?? '').toString().toLowerCase();
        print('   Job Status: $jobStatus');
        
        if (jobStatus != 'open') {
          throw Exception("This job is no longer open for bidding (Status: $jobStatus)");
        }
        print('Job is open for bidding');

        final existingBidSnap = await txn.get(bidRef);
        if (existingBidSnap.exists) {
          throw Exception("You have already placed a bid on this job");
        }
        print('No existing bid found');

        print('💾 Writing bid to Firestore...');
        txn.set(bidRef, {
          'jobId': jobId,
          'caregiverId': caregiverId,
          'amount': amount,
          'proposal': proposal,
          'estimatedDuration': estimatedDuration,
          'status': 'pending', // pending, approved, rejected
          'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print(' Bid written to transaction');

        //  UPDATE JOB DOCUMENT: Track bid metadata so client is notified
        print('💾 Updating job with bid metadata...');
        txn.update(jobRef, {
          'hasPendingBids': true,
          'lastBidAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('Job metadata updated in transaction');
      });

      print('Transaction committed successfully');
      
      // CREATE NOTIFICATION: Notify client about new bid (after transaction succeeds)
      if (clientId.isNotEmpty) {
        await _createBidNotification(
          jobId: jobId,
          jobTitle: jobTitle,
          clientId: clientId,
          caregiverName: caregiverName,
          bidAmount: amount,
        );
      }
      
      print('🎉 ===== BID CREATION COMPLETED =====\n');
      return bidRef.id;
    } catch (e) {
      print('ERROR creating bid: $e');
      print('===== BID CREATION FAILED =====\n');
      rethrow;
    }
  }

  Future<void> updateBid({
    required String jobId,
    required String bidId,
    double? amount,
    String? proposal,
    int? estimatedDuration,
  }) async {
    try {
      final Map<String, dynamic> updates = {
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (amount != null && amount > 0) updates['amount'] = amount;
      if (proposal != null) updates['proposal'] = proposal;
      if (estimatedDuration != null) updates['estimatedDuration'] = estimatedDuration;

      await _db
          .collection('jobs')
          .doc(jobId)
          .collection('bids')
          .doc(bidId)
          .update(updates);
    } catch (e) {
      print('Error updating bid: $e');
      rethrow;
    }
  }

  Future<void> approveBid(String jobId, String bidId) async {
    try {
      if (jobId.isEmpty || bidId.isEmpty) {
        throw Exception("Job ID and Bid ID cannot be empty");
      }

      // Use transaction to ensure atomicity
      await _db.runTransaction((txn) async {
        final jobRef = _db.collection('jobs').doc(jobId);
        final bidRef = jobRef.collection('bids').doc(bidId);

        final jobSnap = await txn.get(jobRef);
        if (!jobSnap.exists) {
          throw Exception("Job not found");
        }

        final jobData = jobSnap.data() ?? <String, dynamic>{};
        final jobStatus = (jobData['status'] ?? '').toString().toLowerCase();
        if (jobStatus != 'open') {
          throw Exception("Job is no longer open");
        }

        final selectedBidSnap = await txn.get(bidRef);
        if (!selectedBidSnap.exists) {
          throw Exception("Selected bid not found");
        }

        final selectedBidData = selectedBidSnap.data() ?? <String, dynamic>{};
        final selectedBidStatus =
            (selectedBidData['status'] ?? '').toString().toLowerCase();
        if (selectedBidStatus != 'pending') {
          throw Exception("Only pending bids can be approved");
        }

        final caregiverId = (selectedBidData['caregiverId'] ?? '').toString();
        if (caregiverId.isEmpty) {
          throw Exception("Selected bid has no caregiver");
        }

        // Update the approved bid
        txn.update(bidRef, {
          'status': 'approved',
          'approvedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Reject all other bids
        final otherBidsSnapshot = await jobRef
            .collection('bids')
            .where('status', isEqualTo: 'pending')
            .get();

        for (var doc in otherBidsSnapshot.docs) {
          if (doc.id != bidId) {
            txn.update(doc.reference, {
              'status': 'rejected',
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }

        // Update job status and assign caregiver
        txn.update(jobRef, {
          'caregiverId': caregiverId,
          'status': 'assigned',
          'hasPendingBids': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      print('Error approving bid: $e');
      rethrow;
    }
  }

  Future<void> rejectBid(String jobId, String bidId) async {
    try {
      await _db
          .collection('jobs')
          .doc(jobId)
          .collection('bids')
          .doc(bidId)
          .update({
        'status': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error rejecting bid: $e');
      rethrow;
    }
  }

  // CREATE NOTIFICATION FOR CLIENT WHEN BID IS PLACED
  Future<void> _createBidNotification({
    required String jobId,
    required String jobTitle,
    required String clientId,
    required String caregiverName,
    required double bidAmount,
  }) async {
    try {
      print('📢 Creating notification for client about new bid...');
      
      // Add notification to client's notifications collection
      await _db
          .collection('users')
          .doc(clientId)
          .collection('notifications')
          .add({
        'type': 'new_bid',
        'jobId': jobId,
        'jobTitle': jobTitle,
        'caregiverName': caregiverName,
        'bidAmount': bidAmount,
        'message': '$caregiverName placed a bid of KES $bidAmount on "$jobTitle"',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      print('Notification created for client');
    } catch (e) {
      print('Warning: Could not create notification: $e');
      // Don't rethrow - notification failure shouldn't block bid creation
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> jobBidsStream(String jobId) {
    return _db
        .collection('jobs')
        .doc(jobId)
        .collection('bids')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getBid(
      String jobId, String bidId) async {
    try {
      return await _db
          .collection('jobs')
          .doc(jobId)
          .collection('bids')
          .doc(bidId)
          .get();
    } catch (e) {
      print('Error getting bid: $e');
      rethrow;
    }
  }

  Future<bool> hasUserBidOnJob(String jobId, String caregiverId) async {
    try {
      final bids = await _db
          .collection('jobs')
          .doc(jobId)
          .collection('bids')
          .where('caregiverId', isEqualTo: caregiverId)
          .limit(1)
          .get();

      return bids.docs.isNotEmpty;
    } catch (e) {
      print('Error checking bid: $e');
      return false;
    }
  }

  // GET CLIENT NOTIFICATIONS ABOUT BIDS
  Stream<QuerySnapshot<Map<String, dynamic>>> clientNotificationsStream(
      String clientId) {
    return _db
        .collection('users')
        .doc(clientId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // GET UNREAD NOTIFICATIONS COUNT
  Future<int> getUnreadNotificationsCount(String clientId) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(clientId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .where('type', isEqualTo: 'new_bid')
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting unread notifications: $e');
      return 0;
    }
  }

  // MARK NOTIFICATION AS READ
  Future<void> markNotificationAsRead(String clientId, String notificationId) async {
    try {
      await _db
          .collection('users')
          .doc(clientId)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // ========================= BID EXPIRATION =========================
  /// Add 7-day expiration to a bid
  Future<void> addBidExpiration(String jobId, String caregiverId) async {
    try {
      final expirationDate = DateTime.now().add(const Duration(days: 7));
      await _db
          .collection('jobs')
          .doc(jobId)
          .collection('bids')
          .doc(caregiverId)
          .update({
            'expiresAt': Timestamp.fromDate(expirationDate),
          });
      print('⏰ Bid expiration set to: $expirationDate');
    } catch (e) {
      print('Error setting bid expiration: $e');
    }
  }

  /// Get caregiver's bids filtered by status with expiration handling
  Stream<QuerySnapshot<Map<String, dynamic>>> getCaregiverBidsWithExpiration(
    String caregiverId,
    String status,
  ) {
    try {
      if (caregiverId.isEmpty) {
        throw Exception("Caregiver ID cannot be empty");
      }

      print('Fetching caregiver bids with expiration: $status');

      return _db
          .collectionGroup('bids')
          .where('caregiverId', isEqualTo: caregiverId)
          .where('status', isEqualTo: status)
          .orderBy('status')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .asyncMap((snapshot) async {
        // Validate and update expired bids on-the-fly
        for (var doc in snapshot.docs) {
          final bidData = doc.data();
          final expiresAt = bidData['expiresAt'] as Timestamp?;

          if (expiresAt != null && expiresAt.toDate().isBefore(DateTime.now())) {
            if (bidData['status'] == 'pending') {
              print('⏰ Auto-expiring bid: ${doc.id}');
              try {
                await doc.reference.update({
                  'status': 'expired',
                  'updatedAt': FieldValue.serverTimestamp(),
                });
              } catch (e) {
                print('Could not auto-expire bid: $e');
              }
            }
          }
        }

        return snapshot;
      });
    } catch (e) {
      print('Error getting caregiver bids with expiration: $e');
      rethrow;
    }
  }

  /// Withdraw a pending bid before expiration
  Future<void> withdrawBid(String jobId, String caregiverId) async {
    try {
      if (jobId.isEmpty || caregiverId.isEmpty) {
        throw Exception("Job ID and Caregiver ID cannot be empty");
      }

      final jobRef = _db.collection('jobs').doc(jobId);
      final bidRef = jobRef.collection('bids').doc(caregiverId);

      await _db.runTransaction((txn) async {
        final bidSnap = await txn.get(bidRef);
        if (!bidSnap.exists) {
          throw Exception("Bid not found");
        }

        final bidData = bidSnap.data() ?? <String, dynamic>{};
        final bidStatus = (bidData['status'] ?? '').toString().toLowerCase();

        if (bidStatus != 'pending') {
          throw Exception(
              "Only pending bids can be withdrawn. Current status: $bidStatus");
        }

        // Update bid status to withdrawn
        txn.update(bidRef, {
          'status': 'withdrawn',
          'withdrawnAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        print('Bid withdrawn: $caregiverId from job: $jobId');
      });
    } catch (e) {
      print('Error withdrawing bid: $e');
      rethrow;
    }
  }

  /// Check and mark expired bids (for client-side validation)
  Future<Map<String, dynamic>> checkAndMarkExpiredBids(
      String jobId, String caregiverId) async {
    try {
      final bidRef = _db.collection('jobs').doc(jobId).collection('bids').doc(caregiverId);
      final bidDoc = await bidRef.get();

      if (!bidDoc.exists) {
        return {'exists': false};
      }

      final bidData = bidDoc.data() ?? <String, dynamic>{};
      final expiresAt = bidData['expiresAt'] as Timestamp?;
      final now = DateTime.now();

      final isExpired = expiresAt != null && expiresAt.toDate().isBefore(now);

      // Update if expired
      if (isExpired && bidData['status'] == 'pending') {
        await bidRef.update({
          'status': 'expired',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('⏰ Bid marked as expired: $caregiverId');
      }

      return {
        'exists': true,
        'status': isExpired ? 'expired' : bidData['status'],
        'expiresAt': expiresAt,
        'isExpired': isExpired,
      };
    } catch (e) {
      print('Error checking bid expiration: $e');
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
      print('Error updating application: $e');
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
      print('Error applying to job: $e');
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
      print('Error hiring caregiver: $e');
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
      print('Error sending message: $e');
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
      print('Error creating conversation: $e');
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
      print('Error getting conversation: $e');
      rethrow;
    }
  }

  Future<void> sendConversationMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
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
        // Add message to subcollection with all required fields
        await txn.set(
          conversationRef.collection('messages').doc(),
          {
            'senderId': senderId,
            'senderName': senderName,
            'text': text,
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
            'readBy': [senderId],
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
      print('Error sending conversation message: $e');
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
  // ========================= CARE PLANS =========================
  Future<String> createCarePlan({
    required String clientId,
    required String type,
    required String title,
    required String description,
    String? time,
    String? frequency,
    bool isCompleted = false,
  }) async {
    try {
      if (clientId.isEmpty) throw Exception("Client ID cannot be empty");
      if (title.isEmpty) throw Exception("Care plan title is required");

      final ref = await _db
          .collection('users')
          .doc(clientId)
          .collection('carePlans')
          .add({
        'type': type,
        'title': title,
        'description': description,
        'time': time,
        'frequency': frequency,
        'isCompleted': isCompleted,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return ref.id;
    } catch (e) {
      print('Error creating care plan: $e');
      rethrow;
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> carePlansStream(String clientId) {
    return _db
        .collection('users')
        .doc(clientId)
        .collection('carePlans')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  Future<void> updateCarePlan(
    String clientId,
    String carePlanId,
    Map<String, dynamic> data,
  ) async {
    try {
      if (clientId.isEmpty || carePlanId.isEmpty) {
        throw Exception("Client ID and Care Plan ID cannot be empty");
      }

      await _db
          .collection('users')
          .doc(clientId)
          .collection('carePlans')
          .doc(carePlanId)
          .update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating care plan: $e');
      rethrow;
    }
  }

  Future<void> toggleCarePlanCompletion(
    String clientId,
    String carePlanId,
    bool isCompleted,
  ) async {
    try {
      await updateCarePlan(clientId, carePlanId, {'isCompleted': isCompleted});
    } catch (e) {
      print('Error toggling care plan completion: $e');
      rethrow;
    }
  }

  Future<void> deleteCarePlan(String clientId, String carePlanId) async {
    try {
      if (clientId.isEmpty || carePlanId.isEmpty) {
        throw Exception("Client ID and Care Plan ID cannot be empty");
      }

      await _db
          .collection('users')
          .doc(clientId)
          .collection('carePlans')
          .doc(carePlanId)
          .delete();
    } catch (e) {
      print('Error deleting care plan: $e');
      rethrow;
    }
  }
}
