import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/payment_model.dart';

/// Service for managing payments and wallet operations in Firestore
class PaymentFirestoreService {
  final _db = FirebaseFirestore.instance;

  /// Create a payment transaction
  Future<PaymentTransaction> createTransaction({
    required String clientId,
    required String caregiverId,
    required double amount,
    required String reference,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Client flow charges platform fee on top of base amount.
      final platformFee = amount * 0.02;
      final caregiverEarnings = amount;

      final transaction = PaymentTransaction(
        id: reference,
        clientId: clientId,
        caregiverId: caregiverId,
        amount: amount,
        caregiverEarnings: caregiverEarnings,
        platformFee: platformFee,
        status: 'pending',
        reference: reference,
        createdAt: DateTime.now(),
        metadata: metadata,
      );

      await _db.collection('transactions').doc(reference).set(transaction.toMap());
      print(' Transaction created: $reference');

      return transaction;
    } catch (e) {
      print(' Error creating transaction: $e');
      rethrow;
    }
  }

  /// Update transaction status
  Future<void> updateTransactionStatus(
    String reference, {
    required String status,
    DateTime? completedAt,
  }) async {
    try {
      await _db.collection('transactions').doc(reference).update({
        'status': status,
        if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt),
      });
      print(' Transaction updated: $reference -> $status');
    } catch (e) {
      print(' Error updating transaction: $e');
      rethrow;
    }
  }

  /// Mark transaction as completed and credit caregiver wallet
  Future<void> completeTransaction(String reference) async {
    try {
      // Get transaction details
      final transactionDoc = await _db.collection('transactions').doc(reference).get();
      if (!transactionDoc.exists) {
        throw Exception('Transaction not found: $reference');
      }

      final transaction = PaymentTransaction.fromMap(
        reference,
        transactionDoc.data()!,
      );

      // Idempotency guard: avoid double wallet credit if completion is retried.
      if (transaction.status == 'completed') {
        print('Transaction already completed: $reference');
        return;
      }

      // Update transaction status
      await updateTransactionStatus(
        reference,
        status: 'completed',
        completedAt: DateTime.now(),
      );

      // Credit caregiver wallet
      await _creditCaregiverWallet(
        transaction.caregiverId,
        transaction.caregiverEarnings,
        reference,
      );

      print('✅ Transaction completed and wallet credited');
    } catch (e) {
      print('🔥 Error completing transaction: $e');
      rethrow;
    }
  }

  /// Credit caregiver wallet with earnings
  Future<void> _creditCaregiverWallet(
    String caregiverId,
    double amount,
    String transactionReference,
  ) async {
    try {
      final walletRef = _db.collection('caregiver_wallets').doc(caregiverId);
      
      // Get or create wallet
      final walletDoc = await walletRef.get();
      
      if (!walletDoc.exists) {
        // Create new wallet
        final newWallet = CaregiverWallet(
          caregiverId: caregiverId,
          balance: amount,
          totalEarnings: amount,
          totalWithdrawn: 0,
          transactionIds: [transactionReference],
          lastUpdated: DateTime.now(),
        );
        await walletRef.set(newWallet.toMap());
        print('✅ New wallet created for caregiver: $caregiverId');
      } else {
        // Update existing wallet
        final wallet = CaregiverWallet.fromMap(walletDoc.data()!);
        final updatedWallet = wallet.addEarnings(amount);
        
        await walletRef.update({
          'balance': updatedWallet.balance,
          'totalEarnings': updatedWallet.totalEarnings,
          'transactionIds': FieldValue.arrayUnion([transactionReference]),
          'lastUpdated': Timestamp.fromDate(DateTime.now()),
        });
        print('✅ Wallet updated for caregiver: $caregiverId (+KES ${amount.toStringAsFixed(2)})');
      }
    } catch (e) {
      print('🔥 Error crediting wallet: $e');
      rethrow;
    }
  }

  /// Get caregiver wallet
  Future<CaregiverWallet?> getCaregiverWallet(String caregiverId) async {
    try {
      final doc = await _db.collection('caregiver_wallets').doc(caregiverId).get();
      if (doc.exists) {
        return CaregiverWallet.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('🔥 Error fetching wallet: $e');
      rethrow;
    }
  }

  /// Get transaction by reference
  Future<PaymentTransaction?> getTransaction(String reference) async {
    try {
      final doc = await _db.collection('transactions').doc(reference).get();
      if (doc.exists) {
        return PaymentTransaction.fromMap(reference, doc.data()!);
      }
      return null;
    } catch (e) {
      print('🔥 Error fetching transaction: $e');
      rethrow;
    }
  }

  /// Get caregiver transactions
  Stream<List<PaymentTransaction>> getCaregiverTransactions(String caregiverId) {
    return _db
        .collection('transactions')
        .where('caregiverId', isEqualTo: caregiverId)
        .where('status', isEqualTo: 'completed')
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PaymentTransaction.fromMap(doc.id, doc.data()))
            .toList());
  }

  /// Get client transactions
  Stream<List<PaymentTransaction>> getClientTransactions(String clientId) {
    return _db
        .collection('transactions')
        .where('clientId', isEqualTo: clientId)
        .where('status', isEqualTo: 'completed')
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PaymentTransaction.fromMap(doc.id, doc.data()))
            .toList());
  }

  /// Stream wallet balance
  Stream<CaregiverWallet?> streamCaregiverWallet(String caregiverId) {
    return _db
        .collection('caregiver_wallets')
        .doc(caregiverId)
        .snapshots()
        .map((doc) => doc.exists ? CaregiverWallet.fromMap(doc.data()!) : null);
  }

  // ==========================================
  // 💰 WITHDRAWAL MANAGEMENT
  // ==========================================

  /// Process a withdrawal request (calls Cloud Function)
  Future<Map<String, dynamic>?> requestWithdrawal({
    required String caregiverId,
    required double amount,
    required String bank,
    required String accountName,
    String? accountNumber,
    String? phoneNumber,
  }) async {
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('processWithdrawal');
      final result = await callable.call(<String, dynamic>{
        'caregiverId': caregiverId,
        'amount': amount,
        'bank': bank,
        'accountName': accountName,
        'accountNumber': accountNumber,
        'phoneNumber': phoneNumber,
      });
      final data = result.data as Map<String, dynamic>?;
      print(' Withdrawal processed: $data');
      return data;
    } catch (e) {
      print(' Withdrawal error: $e');
      return null;
    }
  }

  /// Get withdrawal history
  Future<List<Map<String, dynamic>>> getWithdrawalHistory(String caregiverId) async {
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('getWithdrawalHistory');
      final result = await callable.call(<String, dynamic>{
        'caregiverId': caregiverId,
        'limit': 50,
      });
      final data = result.data as Map<String, dynamic>?;
      final withdrawals = List<Map<String, dynamic>>.from(data?['withdrawals'] ?? []);
      return withdrawals;
    } catch (e) {
      print(' Error fetching withdrawal history: $e');
      return [];
    }
  }

  /// Stream withdrawal history
  Stream<List<Map<String, dynamic>>> streamWithdrawalHistory(String caregiverId) {
    return _db
        .collection('withdrawals')
        .where('caregiverId', isEqualTo: caregiverId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  // ==========================================
  // 📋 AUDIT LOGGING
  // ==========================================

  /// Log audit event for transaction changes
  Future<void> logAuditEvent({
    required String userId,
    required String eventType,
    required String resource,
    required String resourceId,
    required String action,
    Map<String, dynamic>? changes,
    String? details,
  }) async {
    try {
      await _db.collection('audit_logs').add({
        'userId': userId,
        'eventType': eventType, // 'transaction', 'withdrawal', 'refund'
        'resource': resource, // 'transaction', 'withdrawal', 'wallet'
        'resourceId': resourceId,
        'action': action, // 'created', 'updated', 'completed', 'refunded'
        'changes': changes,
        'details': details,
        'timestamp': Timestamp.now(),
        'createdAt': DateTime.now(),
      });
      print('✅ Audit logged: $eventType - $action on $resource');
    } catch (e) {
      print('⚠️  Error logging audit event: $e');
      // Don't rethrow - audit failures shouldn't block operations
    }
  }

  /// Get audit logs for a transaction
  Future<List<Map<String, dynamic>>> getTransactionAuditLog(String transactionId) async {
    try {
      final snapshot = await _db
          .collection('audit_logs')
          .where('resourceId', isEqualTo: transactionId)
          .orderBy('timestamp', descending: true)
          .get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error fetching audit log: $e');
      return [];
    }
  }
}

