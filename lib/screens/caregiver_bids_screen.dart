import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../services/firestore_service.dart';
import '../utils/bid_expiration_helper.dart';

class CaregiverBidsScreen extends StatefulWidget {
  const CaregiverBidsScreen({Key? key}) : super(key: key);

  @override
  State<CaregiverBidsScreen> createState() => _CaregiverBidsScreenState();
}

class _CaregiverBidsScreenState extends State<CaregiverBidsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _firestoreService = FirestoreService();
  late String _caregiverId;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _caregiverId = FirebaseAuth.instance.currentUser?.uid ?? '';

    // Refresh countdown every minute
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_caregiverId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Bids')),
        body: const Center(child: Text('Not logged in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bids'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Rejected'),
            Tab(text: 'Expired'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBidsTab('pending'),
          _buildBidsTab('approved'),
          _buildBidsTab('rejected'),
          _buildBidsTab('expired'),
        ],
      ),
    );
  }

  Widget _buildBidsTab(String status) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestoreService.getCaregiverBidsWithExpiration(_caregiverId, status),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final bids = snapshot.data?.docs ?? [];

        if (bids.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  status == 'pending'
                      ? Icons.assignment_late
                      : status == 'approved'
                          ? Icons.check_circle
                          : status == 'rejected'
                              ? Icons.cancel
                              : Icons.schedule,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No $status bids',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bids.length,
          itemBuilder: (context, index) {
            final bid = bids[index];
            return _buildBidCard(context, bid.data(), bid.id, status);
          },
        );
      },
    );
  }

  Widget _buildBidCard(
    BuildContext context,
    Map<String, dynamic> bidData,
    String bidId,
    String status,
  ) {
    final jobId = bidData['jobId'] ?? '';
    final amount = (bidData['amount'] ?? 0.0).toDouble();
    final proposal = bidData['proposal'] ?? '';
    final estimatedDuration = bidData['estimatedDuration'] ?? 0;
    final expiresAt = bidData['expiresAt'] as Timestamp?;
    final jobTitle = bidData['jobTitle'] ?? 'Job ${jobId.substring(0, 8)}';
    final createdAt = bidData['createdAt'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        jobTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bid ID: ${bidId.substring(0, 8)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(status),
              ],
            ),
            const SizedBox(height: 12),

            // Expiration countdown (if pending and not expired)
            if (status == 'pending' && expiresAt != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildExpirationCountdown(expiresAt),
              ),

            // Bid details box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bid Amount',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'KES ${amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Duration',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$estimatedDuration hours',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Created date
            Text(
              'Created: ${_formatDate(createdAt)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),

            // Proposal
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Proposal',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    proposal,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Action buttons
            if (status == 'pending')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showBidDetails(context, bidData, jobId),
                      icon: const Icon(Icons.visibility),
                      label: const Text('View'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _performWithdrawBid(context, jobId),
                      icon: const Icon(Icons.close),
                      label: const Text('Withdraw'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                      ),
                    ),
                  ),
                ],
              )
            else
              Center(
                child: OutlinedButton.icon(
                  onPressed: () => _showBidDetails(context, bidData, jobId),
                  icon: const Icon(Icons.visibility),
                  label: const Text('View Details'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final statusColor = status == 'pending'
        ? Colors.orange
        : status == 'approved'
            ? Colors.green
            : status == 'rejected'
                ? Colors.red
                : Colors.grey;

    final statusLabel = status == 'pending'
        ? 'PENDING'
        : status == 'approved'
            ? 'APPROVED'
            : status == 'rejected'
                ? 'REJECTED'
                : 'EXPIRED';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor),
      ),
      child: Text(
        statusLabel,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: statusColor,
        ),
      ),
    );
  }

  Widget _buildExpirationCountdown(Timestamp expiresAt) {
    final timeRemaining = BidExpirationHelper.formatTimeRemaining(expiresAt);
    final color = BidExpirationHelper.getExpirationColor(expiresAt);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(
            BidExpirationHelper.getExpirationIcon(expiresAt),
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              timeRemaining,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBidDetails(
      BuildContext context, Map<String, dynamic> bidData, String jobId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bid Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Amount:', 'KES ${bidData['amount']}'),
              _detailRow('Duration:', '${bidData['estimatedDuration']} hours'),
              _detailRow('Status:', bidData['status']?.toString().toUpperCase() ?? ''),
              _detailRow(
                'Created:',
                _formatDate(bidData['createdAt'] as Timestamp?),
              ),
              if (bidData['expiresAt'] != null)
                _detailRow(
                  'Expires:',
                  _formatDate(bidData['expiresAt'] as Timestamp?),
                ),
              const SizedBox(height: 12),
              const Text(
                'Proposal:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(bidData['proposal'] ?? 'No proposal'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _performWithdrawBid(BuildContext context, String jobId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw Bid?'),
        content: const Text(
          'Are you sure you want to withdraw this bid? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _withdrawBid(jobId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
  }

  Future<void> _withdrawBid(String jobId) async {
    try {
      await _firestoreService.withdrawBid(jobId, _caregiverId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Bid withdrawn successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e')),
        );
      }
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final date = timestamp.toDate();
    return DateFormat('MMM dd, yyyy HH:mm').format(date);
  }
}
