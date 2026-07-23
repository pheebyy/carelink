import 'package:carelink/screens/job_detail_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../widgets/ux_components.dart';

class AllJobsScreen extends StatefulWidget {
  const AllJobsScreen({super.key});

  @override
  State<AllJobsScreen> createState() => _AllJobsScreenState();
}

class _AllJobsScreenState extends State<AllJobsScreen> {
  final _fs = FirestoreService();
  final _searchController = TextEditingController();
  String _selectedSortOption = 'Recent';
  String _searchQuery = '';
  bool _isRefreshing = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    
    setState(() => _isRefreshing = true);
    try {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        setState(() {});
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  String _shortError(Object? e) {
    final s = e?.toString() ?? 'Unknown error';
    return s.length > 100 ? '${s.substring(0, 97)}...' : s;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterAndSortDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    // Filter by search query
    var filtered = docs.where((doc) {
      final data = doc.data();
      final title = (data['title'] ?? '').toString().toLowerCase();
      final careType = (data['careType'] ?? '').toString().toLowerCase();
      final location = (data['location'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();

      return title.contains(query) ||
          careType.contains(query) ||
          location.contains(query);
    }).toList();

    // Sort based on selected option
    switch (_selectedSortOption) {
      case 'Recent':
        filtered.sort((a, b) {
          final aTime = a.data()['createdAt'] as Timestamp?;
          final bTime = b.data()['createdAt'] as Timestamp?;
          return (bTime?.millisecondsSinceEpoch ?? 0)
              .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
        });
        break;
      case 'Oldest':
        filtered.sort((a, b) {
          final aTime = a.data()['createdAt'] as Timestamp?;
          final bTime = b.data()['createdAt'] as Timestamp?;
          return (aTime?.millisecondsSinceEpoch ?? 0)
              .compareTo(bTime?.millisecondsSinceEpoch ?? 0);
        });
        break;
      case 'Highest Pay':
        filtered.sort((a, b) {
          final aPay = _getPayValue(a.data());
          final bPay = _getPayValue(b.data());
          return bPay.compareTo(aPay);
        });
        break;
      case 'Lowest Pay':
        filtered.sort((a, b) {
          final aPay = _getPayValue(a.data());
          final bPay = _getPayValue(b.data());
          return aPay.compareTo(bPay);
        });
        break;
    }

    return filtered;
  }

  double _getPayValue(Map<String, dynamic> data) {
    final budget = data['budget'];
    final pay = data['pay'];

    if (budget != null) {
      return (budget is num) ? budget.toDouble() : 0.0;
    }
    if (pay != null) {
      return (pay is num) ? pay.toDouble() : 0.0;
    }
    return 0.0;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterValidDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((doc) {
      final data = doc.data();
      if (data.isEmpty) return false;
      final title = _readString(data['title']);
      if (title.isEmpty) return false;
      return true;
    }).toList();
  }

  String _readString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    return value.toString().trim();
  }

  void _navigateToJobDetail(String jobId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JobDetailScreen(jobId: jobId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stream = _fs.openJobsStream();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('All Jobs'),
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.1),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: Colors.green,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingState();
            }

            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error);
            }

            final querySnap = snapshot.data;
            final docs = querySnap?.docs ?? [];
            final validDocs = _filterValidDocs(docs);
            final filteredDocs = _filterAndSortDocs(validDocs);

            if (validDocs.isEmpty) {
              return _buildEmptyState();
            }

            if (filteredDocs.isEmpty && _searchQuery.isNotEmpty) {
              return _buildNoSearchResultsState();
            }

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildSearchAndFilterHeader(),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '${filteredDocs.length} job${filteredDocs.length != 1 ? 's' : ''} found',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final doc = filteredDocs[index];
                        return _buildJobCard(doc);
                      },
                      childCount: filteredDocs.length,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
            decoration: InputDecoration(
              hintText: 'Search jobs by title, type, or location...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _searchQuery.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      child: const Icon(Icons.clear, color: Colors.grey),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          // Sort dropdown
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButton<String>(
              value: _selectedSortOption,
              isExpanded: true,
              underline: const SizedBox(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              items: ['Recent', 'Oldest', 'Highest Pay', 'Lowest Pay']
                  .map((option) => DropdownMenuItem(
                        value: option,
                        child: Text(option),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedSortOption = value);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              const SkeletonLoader(height: 50, width: 50),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonLoader(height: 14, width: MediaQuery.of(context).size.width * 0.4),
                    const SizedBox(height: 8),
                    SkeletonLoader(height: 12, width: MediaQuery.of(context).size.width * 0.2),
                    const SizedBox(height: 8),
                    SkeletonLoader(height: 12, width: MediaQuery.of(context).size.width * 0.3),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    return ErrorStateWidget(
      error: _shortError(error),
      onRetry: () => setState(() {}),
    );
  }

  Widget _buildEmptyState() {
    return const EmptyStateWidget(
      title: 'No jobs available',
      message: 'Check back later for new opportunities',
      icon: Icons.work_outline,
    );
  }

  Widget _buildNoSearchResultsState() {
    return EmptyStateWidget(
      title: 'No jobs found',
      message: 'Try adjusting your search criteria',
      icon: Icons.search_off,
      actionLabel: 'Clear Search',
      onActionPressed: () {
        _searchController.clear();
        setState(() => _searchQuery = '');
      },
    );
  }

  Widget _buildJobCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final jobId = doc.id;

    final title = _readString(data['title'], fallback: 'Untitled Job');
    final pay = data['budget'] != null
        ? data['budget'].toString()
        : (data['pay'] != null ? data['pay'].toString() : 'Not specified');
    final careType = _readString(data['careType'], fallback: 'Caregiving');
    final status = _readString(data['status'], fallback: 'unknown');
    final location = _readString(data['location'], fallback: 'Not specified');

    return GestureDetector(
      onTap: () => _navigateToJobDetail(jobId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildJobAvatar(),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildJobInfo(title, careType, pay),
                ),
                _buildStatusBadge(status),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on,
                    size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  location,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobAvatar() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.work, color: Colors.green.shade700, size: 28),
    );
  }

  Widget _buildJobInfo(String title, String careType, String pay) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          careType,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Text(
          '\ KES $pay/hr',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = status.toLowerCase() == 'pending'
        ? Colors.orange
        : status.toLowerCase() == 'active'
            ? Colors.green
            : Colors.grey;
    final bgColor = color.withOpacity(0.1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
