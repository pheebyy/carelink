import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Models/job_analytics_model.dart';
import '../services/job_analytics_service.dart';

class CaregiverAnalyticsDashboard extends StatefulWidget {
  const CaregiverAnalyticsDashboard({Key? key}) : super(key: key);

  @override
  State<CaregiverAnalyticsDashboard> createState() =>
      _CaregiverAnalyticsDashboardState();
}

class _CaregiverAnalyticsDashboardState
    extends State<CaregiverAnalyticsDashboard> {
  final _analyticsService = JobAnalyticsService();
  final _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Analytics')),
        body: const Center(child: Text('Please sign in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Performance'),
        elevation: 0,
      ),
      body: StreamBuilder<JobAnalytics?>(
        stream: _analyticsService.streamCaregiverAnalytics(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final analytics = snapshot.data;
          if (analytics == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics_outlined,
                      size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('No job history yet',
                      style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                // Quality Tier Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getQualityColor(analytics.averageRating),
                        _getQualityColor(analytics.averageRating).withOpacity(0.7),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        analytics.getQualityTier(),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${analytics.averageRating.toStringAsFixed(1)}★ • ${analytics.totalReviews} reviews',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),

                // Key Metrics Grid
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Row 1: Jobs & Completion Rate
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Jobs Completed',
                              value: '${analytics.totalJobsCompleted}',
                              icon: Icons.check_circle,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Completion Rate',
                              value: analytics.getCompletionRateString(),
                              icon: Icons.trending_up,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Row 2: Earnings & Active Jobs
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Total Earned',
                              value: 'KES ${(analytics.totalEarnings / 1000).toStringAsFixed(1)}K',
                              icon: Icons.money,
                              color: Colors.amber,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Active Jobs',
                              value: '${analytics.currentlyAcceptedJobs}',
                              icon: Icons.work,
                              color: Colors.purple,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Detailed Breakdown
                      _buildDetailedSection(analytics),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedSection(JobAnalytics analytics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Job Performance',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        _buildDetailRow('Total Jobs Accepted', '${analytics.totalJobsAccepted}'),
        const SizedBox(height: 12),
        _buildDetailRow(
            'Average Rating',
            '${analytics.averageRating.toStringAsFixed(2)} / 5.0',
            valueColor: _getQualityColor(analytics.averageRating)),
        const SizedBox(height: 12),
        _buildDetailRow('Total Reviews Received', '${analytics.totalReviews}'),
        const SizedBox(height: 12),
        _buildDetailRow('Total Earnings', analytics.getFormattedEarnings(),
            valueColor: Colors.green),
        const SizedBox(height: 24),

        // Rating Breakdown Info
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info, color: Colors.blue.shade600, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Every job completed adds to your track record. Higher ratings help you attract more clients.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value,
      {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Color _getQualityColor(double rating) {
    if (rating >= 4.8) return Colors.green.shade600;
    if (rating >= 4.5) return Colors.blue.shade600;
    if (rating >= 4.0) return Colors.amber.shade600;
    return Colors.orange.shade600;
  }
}
