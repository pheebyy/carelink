import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Models/Job_model.dart';
import '../services/job_service.dart';

// Simple model for job applicants
class JobApplicant {
  final String caregiverId;
  final String caregiverName;
  final double rating;
  final int totalReviews;
  final String bio;
  final double proposedRate;

  JobApplicant({
    required this.caregiverId,
    required this.caregiverName,
    required this.rating,
    required this.totalReviews,
    required this.bio,
    required this.proposedRate,
  });
}

class JobApplicantsScreen extends StatefulWidget {
  final JobModel job;

  const JobApplicantsScreen({
    Key? key,
    required this.job,
  }) : super(key: key);

  @override
  State<JobApplicantsScreen> createState() => _JobApplicantsScreenState();
}

class _JobApplicantsScreenState extends State<JobApplicantsScreen> {
  final _jobService = JobService();
  final _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Applicants'),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('job_applications')
            .where('jobId', isEqualTo: widget.job.id)
            .where('status', isEqualTo: 'applied')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final applications = snapshot.data?.docs ?? [];

          if (applications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline,
                      size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('No applicants yet',
                      style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  Text(
                    'Check back later for applicants',
                    style:
                        TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: applications.length,
            itemBuilder: (context, index) {
              final appData = applications[index].data() as Map<String, dynamic>;
              return _buildApplicationCard(
                context,
                applications[index].id,
                appData,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildApplicationCard(
    BuildContext context,
    String applicationId,
    Map<String, dynamic> appData,
  ) {
    final caregiverId = appData['caregiverId'] as String?;
    final caregiverName = appData['caregiverName'] as String? ?? 'Unknown';
    final rating = (appData['caregiverRating'] as num?)?.toDouble() ?? 0.0;
    final totalReviews = appData['caregiverReviews'] as int? ?? 0;
    final bio = appData['caregiverBio'] as String? ?? 'No bio provided';
    final proposedRate = (appData['proposedRate'] as num?)?.toDouble() ?? 0.0;
    final appliedAt = appData['appliedAt'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with name and rating
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        caregiverName,
                        style: Theme.of(context).textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      _buildRatingWidget(rating, totalReviews),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Bio
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'About',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    bio,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Rate and application date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Proposed Rate',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'KES ${proposedRate.toStringAsFixed(0)}/hour',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (appliedAt != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Applied',
                        style:
                            TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getTimeAgo(appliedAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Message'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: caregiverId != null
                        ? () => _hireCaregiver(caregiverId)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('Hire'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingWidget(double rating, int totalReviews) {
    final stars = List.generate(5, (index) {
      final starValue = (index + 1).toDouble();
      final isFilled = starValue <= rating;
      return Icon(
        isFilled ? Icons.star : Icons.star_outline,
        size: 14,
        color: isFilled ? Colors.amber : Colors.grey.shade300,
      );
    });

    return Row(
      children: [
        ...stars,
        const SizedBox(width: 6),
        Text(
          '${rating.toStringAsFixed(1)} ($totalReviews)',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _getTimeAgo(Timestamp timestamp) {
    final difference = DateTime.now().difference(timestamp.toDate());

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 7).floor()}w ago';
    }
  }

  Future<void> _hireCaregiver(String caregiverId) async {
    try {
      await _jobService.hireCaregiver(
        jobId: widget.job.id,
        caregiverId: caregiverId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Caregiver hired successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
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
