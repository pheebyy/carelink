import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/payment_firestore_service.dart';
import '../Models/payment_model.dart';
import 'dispute_and_refund_screen.dart';

/// Screen showing clients their payment history to specific caregivers
class ClientPaymentHistoryScreen extends StatefulWidget {
  final String? clientId;

  const ClientPaymentHistoryScreen({
    Key? key,
    this.clientId,
  }) : super(key: key);

  @override
  State<ClientPaymentHistoryScreen> createState() =>
      _ClientPaymentHistoryScreenState();
}

class _ClientPaymentHistoryScreenState
    extends State<ClientPaymentHistoryScreen> {
  late final PaymentFirestoreService _paymentService;
  late String _clientId;
  String _selectedFilter = 'all'; // all, completed, disputed, refunded

  @override
  void initState() {
    super.initState();
    _paymentService = PaymentFirestoreService();
    final currentUser = FirebaseAuth.instance.currentUser;
    _clientId = widget.clientId ?? currentUser?.uid ?? 'unknown';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment History'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // ===== FILTER TABS =====
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Completed', 'completed'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Disputed', 'disputed'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Refunded', 'refunded'),
                ],
              ),
            ),
          ),

          // ===== PAYMENT LIST =====
          Expanded(
            child: StreamBuilder<List<PaymentTransaction>>(
              stream: _paymentService.getClientTransactions(_clientId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48, color: Colors.red.shade400),
                        const SizedBox(height: 16),
                        Text('Error loading payments: ${snapshot.error}'),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final transactions = snapshot.data ?? [];

                // Filter transactions
                final filteredTransactions = _selectedFilter == 'all'
                    ? transactions
                    : transactions
                        .where((t) => t.status == _selectedFilter)
                        .toList();

                if (filteredTransactions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.payment_outlined,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No $_selectedFilter payments yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Calculate totals
                final totalSpent = filteredTransactions
                    .where((t) => t.status == 'completed')
                    .fold<double>(0, (sum, t) => sum + t.amount)
                    .toStringAsFixed(2);

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredTransactions.length + 1,
                  itemBuilder: (context, index) {
                    // Summary card at top
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildSummaryCard(
                          totalSpent,
                          filteredTransactions.length,
                        ),
                      );
                    }

                    final transaction =
                        filteredTransactions[index - 1];
                    return _buildPaymentCard(transaction);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    return FilterChip(
      label: Text(label),
      selected: _selectedFilter == value,
      onSelected: (selected) {
        setState(() => _selectedFilter = value);
      },
      selectedColor: Colors.blue.shade200,
    );
  }

  Widget _buildSummaryCard(String totalSpent, int paymentCount) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade600, Colors.blue.shade800],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Spent',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'KES $totalSpent',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$paymentCount payments',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard(PaymentTransaction transaction) {
    final isRefunded = transaction.status == 'refunded';
    final statusColor =
        isRefunded ? Colors.orange : Colors.green;
    final statusIcon =
        isRefunded ? Icons.undo : Icons.check_circle;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: isRefunded ? 0 : 1,
      color: isRefunded ? Colors.orange.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Amount & Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KES ${transaction.amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reference: ${transaction.reference}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Icon(statusIcon,
                        color: statusColor, size: 24),
                    const SizedBox(height: 4),
                    Text(
                      transaction.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    'Caregiver ID',
                    transaction.caregiverId,
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    'Amount Paid',
                    'KES ${transaction.amount.toStringAsFixed(2)}',
                    isBold: true,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    'Platform Fee',
                    'KES ${transaction.platformFee.toStringAsFixed(2)}',
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    'Caregiver Gets',
                    'KES ${transaction.caregiverEarnings.toStringAsFixed(2)}',
                    isBold: true,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    'Date',
                    _formatDate(transaction.completedAt ??
                        transaction.createdAt),
                  ),
                  if (isRefunded && transaction.refundReason != null) ...[
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Refund Reason',
                      transaction.refundReason!,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Refunded On',
                      _formatDate(transaction.refundedAt ?? DateTime.now()),
                    ),
                  ],
                ],
              ),
            ),

            // Job details
            if (transaction.metadata != null) ...[
              const SizedBox(height: 12),
              ExpansionTile(
                title: const Text(
                  'Job Details',
                  style: TextStyle(fontSize: 13),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (transaction.metadata?['jobTitle'] != null)
                          Text(
                            '📋 ${transaction.metadata?['jobTitle']}',
                          ),
                        if (transaction.metadata?['jobId'] != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Job ID: ${transaction.metadata?['jobId']}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                        if (transaction.metadata?['verified'] == true) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.verified,
                                  size: 16,
                                  color: Colors.green.shade600),
                              const SizedBox(width: 6),
                              const Text('Payment verified before processing'),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],

            // Action buttons
            const SizedBox(height: 12),
            if (transaction.status == 'completed')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openDisputeFlow(transaction),
                      icon: const Icon(Icons.flag, size: 18),
                      label: const Text('Dispute'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value,
      {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _openDisputeFlow(PaymentTransaction transaction) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DisputeAndRefundScreen(transaction: transaction),
      ),
    ).then((result) {
      if (result != null && result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Dispute filed: ${result['disputeId']}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
