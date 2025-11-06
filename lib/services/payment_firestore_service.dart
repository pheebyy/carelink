import 'package:cloud_firestore/cloud_firestore.dart';
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
      // Calculate caregiver earnings (95% of amount, 5% platform fee)
      final platformFee = amount * 0.05;
      final caregiverEarnings = amount - platformFee;

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
      print('✅ Transaction created: $reference');

      return transaction;
    } catch (e) {
      print('🔥 Error creating transaction: $e');
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
      print('✅ Transaction updated: $reference -> $status');
    } catch (e) {
      print('🔥 Error updating transaction: $e');
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
}
