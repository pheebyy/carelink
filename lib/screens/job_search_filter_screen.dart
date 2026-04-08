import 'package:flutter/material.dart';
import '../Models/Job_model.dart';
import '../services/job_service.dart';

class JobSearchFilterScreen extends StatefulWidget {
  const JobSearchFilterScreen({Key? key}) : super(key: key);

  @override
  State<JobSearchFilterScreen> createState() => _JobSearchFilterScreenState();
}

class _JobSearchFilterScreenState extends State<JobSearchFilterScreen> {
  final _jobService = JobService();
  final _locationController = TextEditingController();
  final _minBudgetController = TextEditingController();
  final _maxBudgetController = TextEditingController();

  String _selectedCareType = 'all';
  String _sortBy = 'newest';
  List<JobModel> _filteredJobs = [];
  bool _isLoading = false;

  final List<String> _careTypes = [
    'all',
    'full-time',
    'part-time',
    'overnight',
    'weekend',
    'temporary'
  ];

  @override
  void initState() {
    super.initState();
    _loadAllJobs();
  }

  Future<void> _loadAllJobs() async {
    setState(() => _isLoading = true);
    try {
      final jobs = await _jobService.getAllOpenJobs().first;
      setState(() {
        _filteredJobs = jobs;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading jobs: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _applyFilters() async {
    setState(() => _isLoading = true);
    try {
      List<JobModel> results = [];

      // Apply care type filter
      if (_selectedCareType != 'all') {
        final typeJobs = await _jobService.getJobsByType(_selectedCareType).first;
        results = typeJobs;
      } else {
        final allJobs = await _jobService.getAllOpenJobs().first;
        results = allJobs;
      }

      // Apply budget filter
      if (_minBudgetController.text.isNotEmpty ||
          _maxBudgetController.text.isNotEmpty) {
        final minBudget = int.tryParse(_minBudgetController.text) ?? 0;
        final maxBudget =
            int.tryParse(_maxBudgetController.text) ?? 999999999;

        if (_selectedCareType != 'all') {
          final budgetJobs = await _jobService
              .searchJobsByBudget(
                minBudget: minBudget,
                maxBudget: maxBudget,
                careType: _selectedCareType,
              )
              .first;
          results = budgetJobs;
        } else {
          results = results
              .where((job) =>
                  (job.budget ?? 0) >= minBudget &&
                  (job.budget ?? 0) <= maxBudget)
              .toList();
        }
      }

      // Apply location filter
      if (_locationController.text.isNotEmpty) {
        final location = _locationController.text.toLowerCase();
        results = results
            .where((job) =>
                (job.location ?? '').toLowerCase().contains(location))
            .toList();
      }

      // Apply sorting
      if (_sortBy == 'newest') {
        results.sort((a, b) =>
            (b.createdAt?.toDate() ?? DateTime(0))
                .compareTo(a.createdAt?.toDate() ?? DateTime(0)));
      } else if (_sortBy == 'budget_high') {
        results.sort((a, b) => (b.budget ?? 0).compareTo(a.budget ?? 0));
      } else if (_sortBy == 'budget_low') {
        results.sort((a, b) => (a.budget ?? 0).compareTo(b.budget ?? 0));
      }

      setState(() {
        _filteredJobs = results;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error applying filters: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedCareType = 'all';
      _locationController.clear();
      _minBudgetController.clear();
      _maxBudgetController.clear();
      _sortBy = 'newest';
    });
    _loadAllJobs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Jobs'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter Section
          Container(
            color: Colors.grey.shade50,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Care Type Filter
                    Text(
                      'Care Type',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _careTypes
                            .map((type) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text(
                                      type
                                          .replaceAll('-', ' ')
                                          .toUpperCase(),
                                    ),
                                    selected: _selectedCareType == type,
                                    onSelected: (selected) {
                                      setState(() {
                                        _selectedCareType = type;
                                      });
                                    },
                                    selectedColor: Colors.blue.shade200,
                                  ),
                                ))
                            .toList(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Location Filter
                    TextFormField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        labelText: 'Location',
                        hintText: 'Search by location...',
                        prefixIcon: const Icon(Icons.location_on),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Budget Range
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _minBudgetController,
                            decoration: InputDecoration(
                              labelText: 'Min Budget',
                              prefixText: 'KES ',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _maxBudgetController,
                            decoration: InputDecoration(
                              labelText: 'Max Budget',
                              prefixText: 'KES ',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Sort By
                    DropdownButtonFormField<String>(
                      value: _sortBy,
                      decoration: InputDecoration(
                        labelText: 'Sort By',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'newest', child: Text('Newest First')),
                        DropdownMenuItem(
                            value: 'budget_high',
                            child: Text('Budget: High to Low')),
                        DropdownMenuItem(
                            value: 'budget_low',
                            child: Text('Budget: Low to High')),
                      ],
                      onChanged: (value) {
                        setState(() => _sortBy = value ?? 'newest');
                      },
                    ),

                    const SizedBox(height: 16),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _clearFilters,
                            child: const Text('Clear All'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _applyFilters,
                            child: const Text('Search'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Results Section
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredJobs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off,
                                size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text('No jobs found',
                                style: TextStyle(
                                    color: Colors.grey.shade600, fontSize: 16)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredJobs.length,
                        itemBuilder: (context, index) {
                          final job = _filteredJobs[index];
                          return _buildJobCard(job);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(JobModel job) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Care Type & Budget
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          job.careType.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        job.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'KES ${job.budget}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Description
            Text(
              job.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),

            const SizedBox(height: 12),

            // Location & Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on,
                        size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        job.location ?? 'Location TBD',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  _formatDate(job.createdAt?.toDate() ?? DateTime.now()),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),

            // Application Count
            const SizedBox(height: 8),
            Text(
              '${job.appliedCaregivers.length} applications',
              style: TextStyle(
                fontSize: 11,
                color: Colors.orange.shade600,
              ),
            ),

            // View Button
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Navigate to job details
                  Navigator.pushNamed(
                    context,
                    '/job-completion',
                    arguments: job,
                  );
                },
                child: const Text('View Details'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inHours < 1) {
      return 'Just now';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _minBudgetController.dispose();
    _maxBudgetController.dispose();
    super.dispose();
  }
}
