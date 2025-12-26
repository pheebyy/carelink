import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/payment_model.dart';

/// Detailed receipt screen for a single payment transaction.
class PaymentReceiptScreen extends StatefulWidget {
  final PaymentTransaction transaction;

  const PaymentReceiptScreen({Key? key, required this.transaction}) : super(key: key);

  @override
  State<PaymentReceiptScreen> createState() => _PaymentReceiptScreenState();
}

class _PaymentReceiptScreenState extends State<PaymentReceiptScreen> {
  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;
    final date = tx.createdAt;
    final formatter = DateFormat('MMM dd, yyyy - HH:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareReceipt,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 48,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Payment ${tx.status.toUpperCase()}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: tx.status.toLowerCase() == 'completed' ? Colors.green : Colors.orange,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                formatter.format(date),
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 32),

            // Amount section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  const Text('Amount Paid', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text(
                    'KES ${tx.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Breakdown
            _buildReceiptRow('Base Amount', 'KES ${tx.amount.toStringAsFixed(2)}'),
            _buildReceiptRow(
              'Platform Fee (5%)',
              'KES ${tx.platformFee.toStringAsFixed(2)}',
              isSubtle: true,
            ),
            Divider(height: 24),
            _buildReceiptRow(
              'Caregiver Earns',
              'KES ${tx.caregiverEarnings.toStringAsFixed(2)}',
              isBold: true,
              color: Colors.green,
            ),
            const SizedBox(height: 32),

            // Details
            Text(
              'Transaction Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Transaction ID', tx.id),
            _buildDetailRow('Reference', tx.reference),
            _buildDetailRow('Status', tx.status.toUpperCase()),
            _buildDetailRow('Date & Time', formatter.format(date)),
            if (tx.completedAt != null)
              _buildDetailRow('Completed', formatter.format(tx.completedAt!)),
            const SizedBox(height: 32),

            // Refund button (if applicable)
            if (tx.status.toLowerCase() == 'completed')
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.undo),
                  label: const Text('Request Refund'),
                  onPressed: _requestRefund,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptRow(
    String label,
    String value, {
    bool isBold = false,
    bool isSubtle = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isSubtle ? Colors.grey : Colors.black87,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? (isSubtle ? Colors.grey : Colors.black87),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _shareReceipt() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share feature coming soon')),
    );
  }

  void _requestRefund() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Refund request submitted. Check your email for updates.')),
    );
  }
}
