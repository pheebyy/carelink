import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Models/payment_model.dart';
import '../services/payment_firestore_service.dart';
import 'payment_receipt_screen.dart';
import 'refund_request_screen.dart';

/// Screen showing payment history for the current user (client).
class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({Key? key}) : super(key: key);

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  final _paymentService = PaymentFirestoreService();
  final _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Payment History')),
        body: const Center(child: Text('Not logged in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment History'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<PaymentTransaction>>(
        stream: _paymentService.getClientTransactions(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return const Center(
              child: Text('Unable to load payment history right now. Please try again.'),
            );
          }

          final transactions = snap.data ?? [];

          if (transactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No payments yet',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final tx = transactions[index];
              return _buildTransactionCard(context, tx);
            },
          );
        },
      ),
    );
  }

  Widget _buildTransactionCard(BuildContext context, PaymentTransaction tx) {
    final statusColor = _getStatusColor(tx.status);
    final statusIcon = _getStatusIcon(tx.status);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(statusIcon, color: statusColor, size: 28),
            ),
            title: Text(
              'KES ${tx.amount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              'Ref: ${tx.reference.substring(0, 20)}...',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tx.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${tx.createdAt.day}/${tx.createdAt.month}/${tx.createdAt.year}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PaymentReceiptScreen(transaction: tx),
              ),
            ),
          ),
          // Refund button for completed payments
          if (tx.status == 'completed')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 36,
                child: ElevatedButton(
                  onPressed: () => _showRefundDialog(context, tx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  child: const Text(
                    'Request Refund',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ),
          // Status messages for other states
          if (tx.status == 'refunded')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.blue.shade600, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Refund processed. Will be credited in 5-7 business days.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showRefundDialog(BuildContext context, PaymentTransaction tx) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Refund?'),
        content: Text(
          'Request a refund for KES ${tx.amount.toStringAsFixed(2)}? You\'ll need to provide a reason.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RefundRequestScreen(transaction: tx),
                ),
              ).then((result) {
                if (result == true && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Refund request submitted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              });
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      case 'refunded':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'pending':
        return Icons.hourglass_top;
      case 'failed':
        return Icons.cancel;
      case 'refunded':
        return Icons.undo;
      default:
        return Icons.help;
    }
  }
}
