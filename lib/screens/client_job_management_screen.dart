import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Models/Job_model.dart';
import '../services/job_service.dart';
import 'review_submission_screen.dart';
import 'job_applicants_screen.dart';

class ClientJobManagementScreen extends StatefulWidget {
  const ClientJobManagementScreen({Key? key}) : super(key: key);

  @override
  State<ClientJobManagementScreen> createState() => _ClientJobManagementScreenState();
}

class _ClientJobManagementScreenState extends State<ClientJobManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _jobService = JobService();
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientId = _auth.currentUser?.uid;
    if (clientId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Jobs')),
        body: const Center(child: Text('Please sign in to manage jobs')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Your Jobs'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
            Tab(text: 'Canceled'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActiveJobsTab(clientId),
          _buildCompletedJobsTab(clientId),
          _buildCanceledJobsTab(clientId),
        ],
      ),
    );
  }

  // ===== Active Jobs Tab =====
  Widget _buildActiveJobsTab(String clientId) {
    return StreamBuilder<List<JobModel>>(
      stream: _jobService.getClientActiveJobs(clientId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final jobs = snapshot.data ?? [];

        if (jobs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.work_outline,
                    size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text('No active jobs',
                    style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                Text(
                  'Post a new job to get started',
                  style:
                      TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: jobs.length,
          itemBuilder: (context, index) {
            final job = jobs[index];
            return _buildActiveJobCard(job, context);
          },
        );
      },
    );
  }

  Widget _buildActiveJobCard(JobModel job, BuildContext context) {
    final statusColor = _getStatusColor(job.status);
    final statusLabel = _getStatusLabel(job.status);
    final isHired = job.status == 'hired' || job.status == 'in-progress';
    final isPendingCompletion = job.status == 'in-progress' &&
        !job.clientConfirmedCompletion &&
        job.caregiverConfirmedCompletion;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        style: Theme.of(context).textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        job.careType,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Job details
            Row(
              children: [
                Expanded(
                  child: _buildDetailItem('Budget', 'KES ${job.budget}/hour'),
                ),
                Expanded(
                  child: _buildDetailItem(
                      'Location', job.location?.split(',').last.trim() ?? 'N/A'),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Caregiver info if hired
            if (isHired && job.caregiverId != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: Colors.green.shade600, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Caregiver Assigned',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          if (job.startDate != null)
                            Text(
                              'Starts: ${_formatDate(job.startDate!)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Pending completion message
            if (isPendingCompletion) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.orange.shade600, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Caregiver marked this complete. Please confirm.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Action buttons
            Row(
              children: [
                if (job.status == 'open' || job.status == 'applied')
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showApplicants(job),
                      child: const Text('View Applicants'),
                    ),
                  ),
                if (isHired && !isPendingCompletion) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showCancelDialog(job),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('Cancel Job'),
                    ),
                  ),
                ],
                if (isPendingCompletion) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _confirmCompletion(job),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: const Text('Confirm Complete'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // ===== Completed Jobs Tab =====
  Widget _buildCompletedJobsTab(String clientId) {
    return StreamBuilder<List<JobModel>>(
      stream: _jobService.getClientCompletedJobs(clientId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final jobs = snapshot.data ?? [];

        if (jobs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text('No completed jobs',
                    style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: jobs.length,
          itemBuilder: (context, index) {
            final job = jobs[index];
            return _buildCompletedJobCard(job, context);
          },
        );
      },
    );
  }

  Widget _buildCompletedJobCard(JobModel job, BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        style: Theme.of(context).textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (job.completedAt != null)
                        Text(
                          'Completed: ${_formatDate(job.completedAt!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.check_circle,
                    color: Colors.green.shade600, size: 24),
              ],
            ),

            const SizedBox(height: 12),

            // Amount
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Paid',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    'KES ${job.budget}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Review button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReviewSubmissionScreen(job: job),
                  ),
                ),
                child: const Text('Leave a Review'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== Canceled Jobs Tab =====
  Widget _buildCanceledJobsTab(String clientId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .where('clientId', isEqualTo: clientId)
          .where('status', isEqualTo: 'canceled')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final jobs = snapshot.data?.docs
                .map((doc) => JobModel.fromDoc(doc))
                .toList() ??
            [];

        if (jobs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cancel_outlined,
                    size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text('No canceled jobs',
                    style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: jobs.length,
          itemBuilder: (context, index) {
            final job = jobs[index];
            return _buildCanceledJobCard(job, context);
          },
        );
      },
    );
  }

  Widget _buildCanceledJobCard(JobModel job, BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        style: Theme.of(context).textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (job.canceledAt != null)
                        Text(
                          'Canceled: ${_formatDate(job.canceledAt!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.cancel, color: Colors.red.shade600, size: 24),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              'Budget: KES ${job.budget}/hour',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  // ===== Helper Methods =====

  Color _getStatusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.blue.shade600;
      case 'applied':
        return Colors.blue.shade500;
      case 'hired':
        return Colors.orange.shade600;
      case 'in-progress':
        return Colors.purple.shade600;
      case 'completed':
        return Colors.green.shade600;
      case 'canceled':
        return Colors.red.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'open':
        return 'Open';
      case 'applied':
        return 'Applications';
      case 'hired':
        return 'Hired';
      case 'in-progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'canceled':
        return 'Canceled';
      default:
        return status;
    }
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _showApplicants(JobModel job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JobApplicantsScreen(job: job),
      ),
    );
  }

  void _showCancelDialog(JobModel job) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Job?'),
        content: const Text(
            'Are you sure you want to cancel this job? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Job'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelJob(job);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Job'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelJob(JobModel job) async {
    try {
      await _jobService.cancelJob(job.id, 'Canceled by client');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job canceled successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmCompletion(JobModel job) async {
    try {
      await _jobService.clientConfirmCompletion(job.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job completion confirmed. You can now review.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
