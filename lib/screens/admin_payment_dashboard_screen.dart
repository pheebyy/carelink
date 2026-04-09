import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Models/payment_model.dart';

/// Admin Dashboard to monitor all payments and verify routing correctness
class AdminPaymentDashboardScreen extends StatefulWidget {
  const AdminPaymentDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminPaymentDashboardScreen> createState() =>
      _AdminPaymentDashboardScreenState();
}

class _AdminPaymentDashboardScreenState
    extends State<AdminPaymentDashboardScreen> {
  final _db = FirebaseFirestore.instance;

  String _selectedFilter = 'all'; // all, pending, completed, failed, refunded
  String _selectedSort = 'newest'; // newest, oldest, highest, lowest
  DateTimeRange? _dateRange;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Payment Dashboard'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterOptions,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Column(
        children: [
          // ===== STATISTICS CARDS =====
          FutureBuilder<Map<String, dynamic>>(
            future: _fetchStatistics(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                );
              }

              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }

              final stats = snapshot.data!;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      _buildStatCard(
                        'Total Revenue',
                        'KES ${(stats['totalRevenue'] as double).toStringAsFixed(2)}',
                        Colors.blue,
                        Icons.trending_up,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        'Transactions',
                        '${stats['totalTransactions']}',
                        Colors.green,
                        Icons.swap_horiz,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        'Pending',
                        '${stats['pendingCount']}',
                        Colors.orange,
                        Icons.schedule,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        'Failed',
                        '${stats['failedCount']}',
                        Colors.red,
                        Icons.error_outline,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        'Refunded',
                        '${stats['refundedCount']}',
                        Colors.purple,
                        Icons.undo,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const Divider(),

          // ===== TRANSACTIONS LIST =====
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildTransactionQuery(),
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
                        Text('Error loading transactions: ${snapshot.error}'),
                      ],
                    ),
                  );
                }

                final transactions = snapshot.data?.docs ?? [];

                if (transactions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No transactions found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final doc = transactions[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final transaction = PaymentTransaction.fromMap(doc.id, data);

                    return _buildTransactionTile(transaction);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _buildTransactionQuery() {
    Query query = _db.collection('transactions');

    // Apply status filter
    if (_selectedFilter != 'all') {
      query = query.where('status', isEqualTo: _selectedFilter);
    }

    // Apply date filter
    if (_dateRange != null) {
      query = query
          .where('createdAt',
              isGreaterThanOrEqualTo:
                  Timestamp.fromDate(_dateRange!.start))
          .where('createdAt',
              isLessThanOrEqualTo:
                  Timestamp.fromDate(_dateRange!.end));
    }

    // Apply sorting
    if (_selectedSort == 'newest') {
      query = query.orderBy('createdAt', descending: true);
    } else if (_selectedSort == 'oldest') {
      query = query.orderBy('createdAt', descending: false);
    } else if (_selectedSort == 'highest') {
      query = query.orderBy('amount', descending: true);
    } else if (_selectedSort == 'lowest') {
      query = query.orderBy('amount', descending: false);
    }

    return query.limit(100).snapshots();
  }

  Future<Map<String, dynamic>> _fetchStatistics() async {
    try {
      final allTx = await _db.collection('transactions').get();
      final docs = allTx.docs;

      double totalRevenue = 0;
      int totalTransactions = 0;
      int pendingCount = 0;
      int failedCount = 0;
      int refundedCount = 0;

      for (var doc in docs) {
        final data = doc.data();
        final status = data['status'] as String?;
        final platformFee = (data['platformFee'] as num?)?.toDouble() ?? 0;

        totalTransactions++;
        totalRevenue += platformFee;

        if (status == 'pending') pendingCount++;
        if (status == 'failed') failedCount++;
        if (status == 'refunded') refundedCount++;
      }

      return {
        'totalRevenue': totalRevenue,
        'totalTransactions': totalTransactions,
        'pendingCount': pendingCount,
        'failedCount': failedCount,
        'refundedCount': refundedCount,
      };
    } catch (e) {
      print('Error fetching statistics: $e');
      return {
        'totalRevenue': 0.0,
        'totalTransactions': 0,
        'pendingCount': 0,
        'failedCount': 0,
        'refundedCount': 0,
      };
    }
  }

  Widget _buildStatCard(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(PaymentTransaction tx) {
    final statusColor = _getStatusColor(tx.status);
    final statusIcon = _getStatusIcon(tx.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Icon(statusIcon, color: statusColor),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'KES ${tx.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Ref: ${tx.reference}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              tx.status.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Client ID', tx.clientId),
                const SizedBox(height: 8),
                _buildDetailRow('Caregiver ID', tx.caregiverId),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Amount',
                  'KES ${tx.amount.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Caregiver Earnings',
                  'KES ${(tx.caregiverEarnings).toStringAsFixed(2)}',
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Platform Fee',
                  'KES ${tx.platformFee.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Created',
                  _formatDate(tx.createdAt),
                ),
                if (tx.completedAt != null) ...[
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    'Completed',
                    _formatDate(tx.completedAt!),
                  ),
                ],
                if (tx.refundReference != null) ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    'Refund Reference',
                    tx.refundReference!,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    'Refund Reason',
                    tx.refundReason ?? 'N/A',
                    color: Colors.orange,
                  ),
                ],

                // ===== ACTION BUTTONS =====
                if (tx.status == 'pending') ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () =>
                              _confirmTransaction(tx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: const Text('Approve'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _rejectTransaction(tx),
                          child: const Text('Reject'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
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
              fontWeight: FontWeight.w600,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Future<void> _confirmTransaction(PaymentTransaction tx) async {
    try {
      await _db
          .collection('transactions')
          .doc(tx.reference)
          .update({
            'status': 'completed',
            'completedAt': Timestamp.now(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Transaction approved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectTransaction(PaymentTransaction tx) async {
    try {
      await _db
          .collection('transactions')
          .doc(tx.reference)
          .update({
            'status': 'failed',
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Transaction rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter by Status',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                _buildFilterChip('All', 'all'),
                _buildFilterChip('Pending', 'pending'),
                _buildFilterChip('Completed', 'completed'),
                _buildFilterChip('Failed', 'failed'),
                _buildFilterChip('Refunded', 'refunded'),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Sort By',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                _buildSortChip('Newest', 'newest'),
                _buildSortChip('Oldest', 'oldest'),
                _buildSortChip('Highest', 'highest'),
                _buildSortChip('Lowest', 'lowest'),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    return FilterChip(
      label: Text(label),
      selected: _selectedFilter == value,
      onSelected: (selected) {
        setState(() => _selectedFilter = value);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildSortChip(String label, String value) {
    return FilterChip(
      label: Text(label),
      selected: _selectedSort == value,
      onSelected: (selected) {
        setState(() => _selectedSort = value);
        Navigator.pop(context);
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      case 'refunded':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'pending':
        return Icons.schedule;
      case 'failed':
        return Icons.error;
      case 'refunded':
        return Icons.undo;
      default:
        return Icons.help_outline;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
