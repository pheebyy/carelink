import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../Models/Job_model.dart';
import '../services/job_service.dart';
import 'job_completion_screen.dart';

class CaregiveActiveJobsScreen extends StatefulWidget {
  const CaregiveActiveJobsScreen({Key? key}) : super(key: key);

  @override
  State<CaregiveActiveJobsScreen> createState() => _CaregiveActiveJobsScreenState();
}

class _CaregiveActiveJobsScreenState extends State<CaregiveActiveJobsScreen>
    with SingleTickerProviderStateMixin {
  final _jobService = JobService();
  late TabController _tabController;

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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Jobs')),
        body: const Center(child: Text('Not logged in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Jobs'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(text: 'Pending Acceptance'),
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Hired (waiting for acceptance)
          _buildHiredJobsList(uid),
          // In-Progress (active)
          _buildActiveJobsList(uid),
          // Completed
          _buildCompletedJobsList(uid),
        ],
      ),
    );
  }

  // Hiring waiting for acceptance
  Widget _buildHiredJobsList(String caregiverId) {
    return StreamBuilder<List<JobModel>>(
      stream: _jobService.getCaregiverHiredJobs(caregiverId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final jobs = snapshot.data ?? [];

        if (jobs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.work_outline,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No pending job offers',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Jobs you\'ve been hired for will appear here',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: jobs.length,
          itemBuilder: (context, index) => _buildJobCard(
            context,
            jobs[index],
            showActions: true,
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () => _acceptJob(jobs[index].id),
                child: const Text('Accept'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _declineJob(jobs[index].id),
                child: const Text('Decline'),
              ),
            ],
          ),
        );
      },
    );
  }

  // Active in-progress jobs
  Widget _buildActiveJobsList(String caregiverId) {
    return StreamBuilder<List<JobModel>>(
      stream: _jobService.getCaregiverActiveJobs(caregiverId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final jobs = snapshot.data ?? [];

        if (jobs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.pause_circle_outline,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No active jobs',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Active jobs will be displayed here',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: jobs.length,
          itemBuilder: (context, index) => _buildJobCard(
            context,
            jobs[index],
            showActions: true,
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => JobCompletionScreen(job: jobs[index]),
                  ),
                ),
                child: const Text('Mark Complete'),
              ),
            ],
          ),
        );
      },
    );
  }

  // Completed jobs
  Widget _buildCompletedJobsList(String caregiverId) {
    return StreamBuilder<List<JobModel>>(
      stream: _jobService.getCaregiverCompletedJobs(caregiverId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final jobs = snapshot.data ?? [];

        if (jobs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No completed jobs yet',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: jobs.length,
          itemBuilder: (context, index) => _buildJobCard(
            context,
            jobs[index],
            showStatus: true,
          ),
        );
      },
    );
  }

  Widget _buildJobCard(
    BuildContext context,
    JobModel job, {
    bool showActions = false,
    List<Widget>? actions,
    bool showStatus = false,
  }) {
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');
    final startDate = job.startDate?.toDate();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'KES ${job.budget ?? 0}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(job.status),
              ],
            ),
            const SizedBox(height: 12),

            // Date & Type
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  startDate != null ? dateFormat.format(startDate) : 'No date set',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.work, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  job.careType,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),

            if (job.location != null && job.location!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    job.location!,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            // Description
            Text(
              job.description,
              style: TextStyle(color: Colors.grey.shade700, height: 1.5),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),

            if (showActions && actions != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  ...actions,
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'hired':
        color = Colors.blue;
        icon = Icons.schedule;
        break;
      case 'in-progress':
        color = Colors.orange;
        icon = Icons.play_circle;
        break;
      case 'completed':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha((0.2 * 255).toInt()),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptJob(String jobId) async {
    try {
      await _jobService.acceptJob(jobId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Job accepted! The job has started.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _declineJob(String jobId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline Job?'),
        content: const Text('Are you sure you want to decline this job? You can\'t undo this.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              try {
                final uid = FirebaseAuth.instance.currentUser!.uid;
                await _jobService.declineJob(jobId, uid);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Job declined'),
                    backgroundColor: Colors.orange,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${e.toString()}')),
                );
              }
            },
            child: const Text('Decline'),
          ),
        ],
      ),
    );
  }
}
