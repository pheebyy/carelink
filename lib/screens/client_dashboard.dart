import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import 'job_detail_screen.dart';
import 'post_job_screen.dart';

class ClientDashboard extends StatefulWidget {
  const ClientDashboard({super.key});

  @override
  State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard> {
  final _fs = FirestoreService();
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  String _selectedFilter = 'all'; // all, active, completed

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Care Jobs'),
        backgroundColor: Colors.green.shade600,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PostJobScreen()),
              );
            },
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Post New Job',
          ),
          IconButton(
            onPressed: () {
              // Profile or settings
            },
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
          )
        ],
      ),
      body: _uid == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.login, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Please login again'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('Go Back'),
                  )
                ],
              ),
            )
          : Column(
              children: [
                // Filter chips
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All Jobs', 'all'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Active', 'active'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Completed', 'completed'),
                      ],
                    ),
                  ),
                ),
                // Jobs list
                Expanded(
                  child: StreamBuilder(
                    stream: _fs.clientJobsStream(_uid!),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.green,
                          ),
                        );
                      }

                      if (!snapshot.hasData) {
                        return _buildEmptyState();
                      }

                      final docs = (snapshot.data as dynamic).docs as List;
                      
                      // Filter jobs based on selected filter
                      final filteredDocs = docs.where((doc) {
                        final status = doc['status'] as String?;
                        if (_selectedFilter == 'all') return true;
                        if (_selectedFilter == 'active') {
                          return status == 'active' || status == 'open';
                        }
                        if (_selectedFilter == 'completed') {
                          return status == 'completed' || status == 'closed';
                        }
                        return true;
                      }).toList();

                      if (filteredDocs.isEmpty) {
                        return _buildEmptyState();
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          final doc = filteredDocs[index];
                          final d = doc.data();
                          final jobId = doc.id;
                          return _buildJobCard(context, d, jobId);
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
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      backgroundColor: Colors.white,
      selectedColor: Colors.green.shade100,
      labelStyle: TextStyle(
        color: isSelected ? Colors.green.shade700 : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
      ),
      side: BorderSide(
        color: isSelected ? Colors.green.shade400 : Colors.grey.shade300,
      ),
    );
  }

  Widget _buildJobCard(BuildContext context, dynamic data, String jobId) {
    final title = data['title'] ?? 'Untitled Job';
    final careType = data['careType'] ?? 'Not specified';
    final status = data['status'] ?? 'open';
    final location = data['location'] ?? 'Location not specified';
    final salary = data['salary'] ?? 'Negotiable';
    final applicantCount = data['applicantCount'] ?? 0;

    // Status badge color
    Color statusColor = Colors.orange;
    if (status == 'completed' || status == 'closed') {
      statusColor = Colors.grey;
    } else if (status == 'active' || status == 'open') {
      statusColor = Colors.green;
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => JobDetailScreen(jobId: jobId),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Title and Status
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 12),
              // Care type and location
              Row(
                children: [
                  Icon(Icons.local_activity, size: 16, color: Colors.green.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      careType,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Location
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      location,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Footer: Salary and applicant count
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Salary',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        salary,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.people, size: 16, color: Colors.blue.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '$applicantCount',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.work_outline,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No jobs yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Post a new caregiving job to get started',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PostJobScreen()),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Post Your First Job'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}