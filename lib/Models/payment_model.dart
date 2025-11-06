import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a payment transaction in CareLink
class PaymentTransaction {
  final String id;
  final String clientId;
  final String caregiverId;
  final double amount; // Amount in KES
  final double caregiverEarnings;
  final double platformFee;
  final String status; // 'pending', 'completed', 'failed'
  final String reference;
  final DateTime createdAt;
  final DateTime? completedAt;
  final Map<String, dynamic>? metadata;

  PaymentTransaction({
    required this.id,
    required this.clientId,
    required this.caregiverId,
    required this.amount,
    required this.caregiverEarnings,
    required this.platformFee,
    required this.status,
    required this.reference,
    required this.createdAt,
    this.completedAt,
    this.metadata,
  });

  /// Convert to Firestore document
  Map<String, dynamic> toMap() => {
    'clientId': clientId,
    'caregiverId': caregiverId,
    'amount': amount,
    'caregiverEarnings': caregiverEarnings,
    'platformFee': platformFee,
    'status': status,
    'reference': reference,
    'createdAt': Timestamp.fromDate(createdAt),
    'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    'metadata': metadata ?? {},
  };

  /// Create from Firestore document
  factory PaymentTransaction.fromMap(String id, Map<String, dynamic> map) =>
      PaymentTransaction(
        id: id,
        clientId: map['clientId'] ?? '',
        caregiverId: map['caregiverId'] ?? '',
        amount: (map['amount'] ?? 0).toDouble(),
        caregiverEarnings: (map['caregiverEarnings'] ?? 0).toDouble(),
        platformFee: (map['platformFee'] ?? 0).toDouble(),
        status: map['status'] ?? 'pending',
        reference: map['reference'] ?? '',
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
        metadata: map['metadata'],
      );
}

/// Represents a caregiver's wallet
class CaregiverWallet {
  final String caregiverId;
  final double balance; // Available balance in KES
  final double totalEarnings;
  final double totalWithdrawn;
  final List<String> transactionIds; // References to payment transactions
  final DateTime lastUpdated;

  CaregiverWallet({
    required this.caregiverId,
    required this.balance,
    required this.totalEarnings,
    required this.totalWithdrawn,
    required this.transactionIds,
    required this.lastUpdated,
  });

  /// Convert to Firestore document
  Map<String, dynamic> toMap() => {
    'caregiverId': caregiverId,
    'balance': balance,
    'totalEarnings': totalEarnings,
    'totalWithdrawn': totalWithdrawn,
    'transactionIds': transactionIds,
    'lastUpdated': Timestamp.fromDate(lastUpdated),
  };

  /// Create from Firestore document
  factory CaregiverWallet.fromMap(Map<String, dynamic> map) =>
      CaregiverWallet(
        caregiverId: map['caregiverId'] ?? '',
        balance: (map['balance'] ?? 0).toDouble(),
        totalEarnings: (map['totalEarnings'] ?? 0).toDouble(),
        totalWithdrawn: (map['totalWithdrawn'] ?? 0).toDouble(),
        transactionIds: List<String>.from(map['transactionIds'] ?? []),
        lastUpdated: (map['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  /// Add earnings to wallet
  CaregiverWallet addEarnings(double amount) => CaregiverWallet(
    caregiverId: caregiverId,
    balance: balance + amount,
    totalEarnings: totalEarnings + amount,
    totalWithdrawn: totalWithdrawn,
    transactionIds: transactionIds,
    lastUpdated: DateTime.now(),
  );
}
