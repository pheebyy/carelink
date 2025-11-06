import 'package:carelink/screens/job_detail_screen.dart';
import 'package:carelink/screens/profile_edit_screen.dart';
import 'package:carelink/screens/all_jobs_screen.dart';
import 'package:carelink/screens/conversations_inbox_screen.dart';
import 'package:carelink/screens/caregiver_wallet_screen.dart';
import 'package:carelink/screens/search_caregivers_screen.dart';
import 'package:carelink/widgets/ai_assistant_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/firestore_service.dart';
import '../services/ai_service.dart';

// Constants
class _Constants {
  static const int maxJobsPreview = 5;
  static const int errorMessageLength = 100;
  static const Duration refreshDelay = Duration(milliseconds: 400);
  static const String openStatus = 'open';
  static const String pendingStatus = 'pending';
}

class CaregiverDashboard extends StatefulWidget {
  const CaregiverDashboard({super.key});

  @override
  State<CaregiverDashboard> createState() => _CaregiverDashboardState();
}

class _CaregiverDashboardState extends State<CaregiverDashboard> {
  late final FirestoreService _fs;
  late final AiService _aiService;
  late PageController _pageController;

  int _currentNavIndex = 0;
  bool _isRefreshing = false;
  bool _showAiAssistant = false;
  int _retryCounter = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fs = FirestoreService();
    _initializeAiService();
  }

  void _initializeAiService() {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        _logWarning('GEMINI_API_KEY not found in environment');
      }
      _aiService = AiService(apiKey: apiKey);
    } catch (e) {
      _logError('Error initializing AI Service', e);
      _aiService = AiService(apiKey: '');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ==================== Logging Methods ====================
  void _logError(String message, Object error) {
    debugPrint('❌ $message: $error');
  }

  void _logWarning(String message) {
    debugPrint('⚠️ $message');
  }

  // ==================== Navigation Methods ====================
  void _handleNavigation(int index) {
    if (_currentNavIndex == index) return;

    setState(() => _currentNavIndex = index);

    switch (index) {
      case 0:
        break;
      case 1:
        _navigateToScreen(const AllJobsScreen());
        break;
      case 2:
        _navigateToScreen(const ConversationsInboxScreen());
        break;
      case 3:
        _navigateToScreen(const CaregiverWalletScreen());
        break;
      case 4:
        _navigateToProfile();
        break;
    }
  }

  void _navigateToScreen(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _navigateToProfile() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
    );
    if (result == true && mounted) {
      await _refresh();
    }
  }

  void _navigateToJobDetail(String jobId) {
    _navigateToScreen(JobDetailScreen(jobId: jobId));
  }

  void _navigateToAllJobs() {
    _navigateToScreen(const AllJobsScreen());
  }

  void _navigateToSearchCaregivers() {
    _navigateToScreen(const SearchCaregiversScreen());
  }

  // ==================== Data Processing Methods ====================
  int _getPendingCount(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return docs.where((doc) {
      final status = _safeReadString(doc.data()['status']);
      return status.toLowerCase() == _Constants.pendingStatus;
    }).length;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterValidDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((d) {
      try {
        return d.data().isNotEmpty;
      } catch (_) {
        return false;
      }
    }).toList();
  }

  String _safeReadString(Object? value, {String fallback = 'N/A'}) {
    try {
      if (value == null) return fallback;
      if (value is String) return value;
      return value.toString();
    } catch (_) {
      return fallback;
    }
  }

  String _truncateError(Object? error) {
    final message = error?.toString() ?? 'Unknown error';
    if (message.length > _Constants.errorMessageLength) {
      return '${message.substring(0, _Constants.errorMessageLength - 3)}...';
    }
    return message;
  }

  // ==================== Refresh & State Methods ====================
  Future<void> _refresh() async {
    if (_isRefreshing || !mounted) return;

    setState(() => _isRefreshing = true);
    try {
      await Future.delayed(_Constants.refreshDelay);
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _showSnackBar(String message,
      {Duration duration = const Duration(seconds: 2),
      Color backgroundColor = Colors.orange}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ==================== Build Methods ====================
  @override
  Widget build(BuildContext context) {
    final stream = _fs.openJobsStream();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _buildAppBar(),
      body: _showAiAssistant
          ? _buildAiAssistantView()
          : _buildMainContent(stream),
      floatingActionButton: _buildAiAssistantFab(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildMainContent(
    Stream<QuerySnapshot<Map<String, dynamic>>> stream,
  ) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: Colors.green,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        key: ValueKey(_retryCounter),
        stream: stream,
        builder: (context, snapshot) {
          return _buildStreamContent(snapshot);
        },
      ),
    );
  }

  Widget _buildStreamContent(
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return _buildLoadingState();
    }

    if (snapshot.hasError) {
      return _buildErrorState(snapshot.error);
    }

    final docs = snapshot.data?.docs ?? [];
    final validDocs = _filterValidDocs(docs);

    if (validDocs.isEmpty) {
      return _buildEmptyState();
    }

    return _buildJobsView(validDocs);
  }

  // ==================== State Views ====================
  Widget _buildLoadingState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.green),
              SizedBox(height: 16),
              Text('Loading jobs...'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline,
                    size: 60,
                    color: Colors.red.shade400,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Something went wrong',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _truncateError(error),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _retryCounter++),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.work_outline_rounded,
                    size: 80,
                    color: Colors.green.shade400,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'No Jobs Available',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Check back soon for new caregiving opportunities',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Refresh'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _navigateToAllJobs,
                      icon: const Icon(Icons.explore),
                      label: const Text('Browse All'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJobsView(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> validDocs,
  ) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchBar(),
            const SizedBox(height: 24),
            _buildStatsSection(validDocs),
            const SizedBox(height: 24),
            _buildSectionHeader('Next Up', _navigateToAllJobs),
            const SizedBox(height: 12),
            _buildJobsList(validDocs),
            const SizedBox(height: 20),
            _buildPrimaryActionButton(validDocs),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ==================== Component Builders ====================
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.menu, color: Colors.grey.shade800),
        onPressed: () => _showSnackBar('Menu feature coming soon'),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Caregivers Dashboard',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Text(
            'Today • ${DateTime.now().toString().split(' ')[0]}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
      centerTitle: false,
      actions: [
        IconButton(
          icon: Icon(Icons.notifications_outlined,
              color: Colors.grey.shade800),
          onPressed: () =>
              _showSnackBar('Notifications feature coming soon'),
        ),
      ],
    );
  }

  Widget _buildAiAssistantFab() {
    return FloatingActionButton(
      heroTag: 'ai_fab',
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
      onPressed: () => setState(() => _showAiAssistant = !_showAiAssistant),
      tooltip: _showAiAssistant ? 'Close AI Assistant' : 'Open AI Assistant',
      child: Icon(_showAiAssistant ? Icons.close : Icons.smart_toy),
    );
  }

  Widget _buildAiAssistantView() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: AiAssistantWidget(aiService: _aiService),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      backgroundColor: Colors.white,
      type: BottomNavigationBarType.fixed,
      currentIndex: _currentNavIndex,
      selectedItemColor: Colors.green,
      unselectedItemColor: Colors.grey.shade600,
      elevation: 8,
      onTap: _handleNavigation,
      items: const [
        BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.work_outline), label: 'Jobs'),
        BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline), label: 'Messages'),
        BottomNavigationBarItem(
            icon: Icon(Icons.wallet_giftcard_outlined), label: 'Wallet'),
        BottomNavigationBarItem(
            icon: Icon(Icons.person_outline), label: 'Profile'),
      ],
    );
  }

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: _navigateToSearchCaregivers,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: Colors.grey.shade600, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Search caregivers by location...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
            Icon(Icons.tune, color: Colors.green.shade600, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> validDocs,
  ) {
    final pendingCount = _getPendingCount(validDocs);
    final completionPercent = validDocs.isEmpty
        ? 0
        : (((validDocs.length - pendingCount) / validDocs.length) * 100)
            .toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Progress',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.visibility,
                label: 'Visits',
                value: '${validDocs.length}',
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.pending_actions,
                label: 'Pending',
                value: '$pendingCount',
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.trending_up,
                label: 'Completion',
                value: '$completionPercent%',
                color: Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onViewAll) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.arrow_forward, color: Colors.grey.shade800, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: onViewAll,
          child: Text(
            'View all',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildJobsList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> validDocs,
  ) {
    final displayCount = validDocs.length > _Constants.maxJobsPreview
        ? _Constants.maxJobsPreview
        : validDocs.length;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: displayCount,
      itemBuilder: (context, index) => _buildJobCard(validDocs[index]),
    );
  }

  Widget _buildJobCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final jobId = doc.id;

    final title = _safeReadString(data['title'], fallback: 'Untitled Job');
    final pay = _safeReadString(
      data['budget'] ?? data['pay'],
      fallback: 'Not specified',
    );
    final careType = _safeReadString(data['careType'], fallback: 'Caregiving');
    final status = _safeReadString(data['status']);
    final postedTime = _safeReadString(data['postedTime'], fallback: 'Recently');

    return GestureDetector(
      onTap: () => _navigateToJobDetail(jobId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildJobAvatar(title),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: _buildJobInfo(title, careType, pay, postedTime),
            ),
            Expanded(
              flex: 1,
              child: Align(
                alignment: Alignment.centerRight,
                child: _buildStatusBadge(status),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobAvatar(String title) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          title.isNotEmpty ? title[0].toUpperCase() : '?',
          style: TextStyle(
            color: Colors.green.shade600,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildJobInfo(String title, String careType, String pay, String postedTime) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Flexible(
          child: Text(
            '$careType • Ksh $pay',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          postedTime,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    final isOpen = status.toLowerCase() == _Constants.openStatus;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOpen ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: isOpen ? Colors.green : Colors.orange,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildPrimaryActionButton(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> validDocs,
  ) {
    final isEnabled = validDocs.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade400,
            Colors.green.shade600,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap:
              isEnabled ? () => _navigateToJobDetail(validDocs[0].id) : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Start Looking for Jobs',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}