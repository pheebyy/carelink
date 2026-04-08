import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/payment_firestore_service.dart';

class WithdrawalHistoryScreen extends StatefulWidget {
  final String caregiverId;

  const WithdrawalHistoryScreen({
    Key? key,
    required this.caregiverId,
  }) : super(key: key);

  @override
  State<WithdrawalHistoryScreen> createState() => _WithdrawalHistoryScreenState();
}

class _WithdrawalHistoryScreenState extends State<WithdrawalHistoryScreen> {
  late PaymentFirestoreService _paymentService;

  @override
  void initState() {
    super.initState();
    _paymentService = PaymentFirestoreService();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Withdrawal History'),
        elevation: 0,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _paymentService.streamWithdrawalHistory(widget.caregiverId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          final withdrawals = snapshot.data ?? [];

          if (withdrawals.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No withdrawal history',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your withdrawal requests will appear here',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: withdrawals.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final withdrawal = withdrawals[index];
              final withdrawalId = withdrawal['id'] as String;
              final amount = (withdrawal['amount'] as num?)?.toDouble() ?? 0.0;
              final bank = withdrawal['bank'] as String? ?? 'Unknown';
              final accountName = withdrawal['accountName'] as String? ?? '';
              final status = withdrawal['status'] as String? ?? 'pending';
              
              // Convert Firestore Timestamp to DateTime
              DateTime? createdAt;
              final createdAtValue = withdrawal['createdAt'];
              if (createdAtValue is Timestamp) {
                createdAt = createdAtValue.toDate();
              } else if (createdAtValue is DateTime) {
                createdAt = createdAtValue;
              }

              return _WithdrawalCard(
                withdrawalId: withdrawalId,
                amount: amount,
                bank: bank,
                accountName: accountName,
                status: status,
                createdAt: createdAt,
              );
            },
          );
        },
      ),
    );
  }
}

class _WithdrawalCard extends StatelessWidget {
  final String withdrawalId;
  final double amount;
  final String bank;
  final String accountName;
  final String status;
  final DateTime? createdAt;

  const _WithdrawalCard({
    Key? key,
    required this.withdrawalId,
    required this.amount,
    required this.bank,
    required this.accountName,
    required this.status,
    required this.createdAt,
  }) : super(key: key);

  Color _getStatusColor() {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      case 'processing':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'pending':
        return Icons.schedule;
      case 'rejected':
        return Icons.cancel;
      case 'processing':
        return Icons.sync;
      default:
        return Icons.help_outline;
    }
  }

  String _getStatusLabel() {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Completed';
      case 'pending':
        return 'Pending';
      case 'rejected':
        return 'Rejected';
      case 'processing':
        return 'Processing';
      default:
        return 'Unknown';
    }
  }

  String _getStatusDescription() {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Amount transferred to your account';
      case 'pending':
        return 'Awaiting approval (1-24 hours)';
      case 'rejected':
        return 'Request was not approved';
      case 'processing':
        return 'Transfer in progress';
      default:
        return 'Unknown status';
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final formattedDate = createdAt != null
        ? DateFormat('MMM dd, yyyy • hh:mm a').format(createdAt!)
        : 'Date unknown';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Amount & Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KES ${amount.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedDate,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha((0.2 * 255).toInt()),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStatusIcon(),
                        size: 16,
                        color: statusColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getStatusLabel(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Divider
            Container(
              height: 1,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),

            // Bank & Account Details
            Row(
              children: [
                Icon(
                  Icons.account_balance,
                  size: 18,
                  color: Colors.grey.shade700,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bank / Method',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        bank,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Account Holder
            if (accountName.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.person,
                    size: 18,
                    color: Colors.grey.shade700,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account Holder',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          accountName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],

            // Status Message
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withAlpha((0.1 * 255).toInt()),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: statusColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getStatusDescription(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Withdrawal ID
            const SizedBox(height: 12),
            Text(
              'ID: $withdrawalId',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
