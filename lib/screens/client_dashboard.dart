import 'package:carelink/screens/ClientProfileEditScreen.dart';
import 'package:carelink/screens/ai_assistant_screen.dart';
import 'package:carelink/screens/conversations_chat_screen.dart';
import 'package:carelink/screens/conversations_inbox_screen.dart';
import 'package:carelink/screens/visits_screen.dart';
import 'package:carelink/screens/search_caregivers_screen.dart';
import 'package:carelink/screens/post_job_screen.dart';
import 'package:carelink/screens/client_payment_history_screen.dart';
import 'package:carelink/screens/client_job_management_screen.dart';
import 'package:carelink/screens/care_plan_screen.dart';
import 'package:carelink/services/firestore_service.dart';
import 'package:carelink/widgets/ux_components.dart';
import 'package:carelink/app_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ClientDashboard extends ConsumerStatefulWidget {
  final bool showBottomNav;
  const ClientDashboard({super.key, this.showBottomNav = false});

  @override
  ConsumerState<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends ConsumerState<ClientDashboard> {
  final _fs = FirestoreService();
  int _currentNavIndex = 0;

  User? get _currentUser => FirebaseAuth.instance.currentUser;
  String? get _uid => _currentUser?.uid;
  String get _userName => _currentUser?.displayName?.isNotEmpty == true
      ? _currentUser!.displayName!
      : 'Client';

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: _buildAppBar(),
        body: _buildLoginRequiredWidget(),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _refreshDashboard,
        color: const Color(0xFF10B981),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroHeader(),
              const SizedBox(height: 20),
              _buildStatsOverview(),
              const SizedBox(height: 24),
              _buildQuickActionsGrid(),
              const SizedBox(height: 24),
              _buildUpcomingVisitsSection(),
              const SizedBox(height: 24),
              _buildPostedJobsSection(),
              const SizedBox(height: 24),
              _buildRecentMessagesSection(),
              const SizedBox(height: 24),
              _buildCarePlanSection(),
              const SizedBox(height: 24),
              _buildAiAssistantSection(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      bottomNavigationBar: widget.showBottomNav ? _buildBottomNavigationBar() : null,
    );
  }

  Future<void> _refreshDashboard() async {
    await Future.delayed(const Duration(milliseconds: 350));
    if (mounted) setState(() {});
  }

  // ==================== Top Bar & Hero ====================

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFF8FAFC),
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Row(
        children: [
          GestureDetector(
            onTap: _navigateToProfile,
            child: CircleAvatar(
              radius: 19,
              backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
              backgroundImage: _currentUser?.photoURL != null
                  ? NetworkImage(_currentUser!.photoURL!)
                  : null,
              child: _currentUser?.photoURL == null
                  ? const Icon(Icons.person, color: Color(0xFF10B981), size: 22)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Carelink Client',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  'Hello, $_userName',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        _buildNotificationBell(),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildNotificationBell() {
    final unreadCount = ref.watch(unreadNotificationsCountProvider).value ?? 0;

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Color(0xFF334155), size: 22),
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
            tooltip: 'Notifications',
          ),
        ),
        if (unreadCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF065F46), Color(0xFF047857), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Verified Care Network',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.favorite_rounded, color: Colors.white70, size: 22),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Need Trusted Care for Your Loved Ones?',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Post a care requirement or browse certified nurses, sitters, and caregivers near you.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _navigateToPostJob,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF065F46),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text(
                    'Post a Job',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _navigateToCaregivers,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text(
                    'Find Caregiver',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== Live Stats Overview ====================

  Widget _buildStatsOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overview',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Visits Today',
                icon: Icons.calendar_today_rounded,
                accentColor: const Color(0xFF3B82F6),
                stream: _getVisitsToday(),
                onTap: _navigateToVisits,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                title: 'Active Jobs',
                icon: Icons.work_outline_rounded,
                accentColor: const Color(0xFF10B981),
                stream: _getActiveJobsCount(),
                onTap: _navigateToJobManagement,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Unread Chats',
                icon: Icons.chat_bubble_outline_rounded,
                accentColor: const Color(0xFF8B5CF6),
                stream: _getUnreadMessagesCount(),
                onTap: _navigateToMessages,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                title: 'Care Plans',
                icon: Icons.favorite_border_rounded,
                accentColor: const Color(0xFFF59E0B),
                stream: _getCarePlansCount(),
                onTap: _navigateToCarePlans,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required IconData icon,
    required Color accentColor,
    required Stream<int> stream,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StreamBuilder<int>(
                      stream: stream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Container(
                            width: 24,
                            height: 20,
                            margin: const EdgeInsets.only(bottom: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }
                        final count = snapshot.data ?? 0;
                        return Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                          ),
                        );
                      },
                    ),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== 2x2 Quick Actions ====================

  Widget _buildQuickActionsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: [
            _buildActionTile(
              title: 'Post a Care Job',
              subtitle: 'Create customized care request',
              icon: Icons.post_add_rounded,
              color: const Color(0xFF10B981),
              onTap: _navigateToPostJob,
            ),
            _buildActionTile(
              title: 'Find Caregivers',
              subtitle: 'Search verified specialists',
              icon: Icons.person_search_rounded,
              color: const Color(0xFF3B82F6),
              onTap: _navigateToCaregivers,
            ),
            _buildActionTile(
              title: 'Care Plans',
              subtitle: 'Manage routines & medications',
              icon: Icons.healing_rounded,
              color: const Color(0xFF8B5CF6),
              onTap: _navigateToCarePlans,
            ),
            _buildActionTile(
              title: 'Payment History',
              subtitle: 'Invoices & transaction records',
              icon: Icons.receipt_long_rounded,
              color: const Color(0xFFF59E0B),
              onTap: _navigateToPaymentHistory,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  Icon(Icons.arrow_outward_rounded, size: 16, color: color),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== Upcoming Visits ====================

  Widget _buildUpcomingVisitsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.event_note_rounded, color: Color(0xFF0F172A), size: 20),
                SizedBox(width: 8),
                Text(
                  'Upcoming Visits',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: _navigateToVisits,
              child: const Text(
                'See all',
                style: TextStyle(
                  color: Color(0xFF10B981),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildUpcomingVisitsList(),
      ],
    );
  }

  Widget _buildUpcomingVisitsList() {
    if (_uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('visits')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            children: List.generate(
              2,
              (index) => const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: SkeletonLoader(height: 84),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return ErrorStateWidget(
            error: 'Unable to load visits',
            onRetry: () => setState(() {}),
          );
        }

        var docs = snapshot.data?.docs ?? [];
        final now = DateTime.now();

        // Filter for upcoming or scheduled visits
        var visits = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) return false;
          final status = (data['status'] as String? ?? '').toLowerCase();
          final time = (data['dateTime'] as Timestamp?)?.toDate();
          return status != 'cancelled' && status != 'completed' && (time == null || time.isAfter(now.subtract(const Duration(hours: 2))));
        }).toList();

        visits.sort((a, b) {
          final timeA = ((a.data() as Map<String, dynamic>)['dateTime'] as Timestamp?)?.toDate() ?? DateTime(2099);
          final timeB = ((b.data() as Map<String, dynamic>)['dateTime'] as Timestamp?)?.toDate() ?? DateTime(2099);
          return timeA.compareTo(timeB);
        });

        visits = visits.take(3).toList();

        if (visits.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Icon(Icons.event_available_rounded, size: 40, color: Colors.grey.shade400),
                const SizedBox(height: 10),
                const Text(
                  'No Upcoming Visits Scheduled',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Book verified care specialists or post a new care need.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: _navigateToCaregivers,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.search, size: 16),
                  label: const Text('Schedule Care Visit', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          );
        }

        return Column(
          children: visits.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final time = data['dateTime'] as Timestamp?;
            final caregiverName = data['caregiverName'] ?? 'Assigned Caregiver';
            final serviceType = data['serviceType'] ?? 'Care Visit';
            final status = (data['status'] as String? ?? 'scheduled').toLowerCase();
            final caregiverId = data['caregiverId'] as String?;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildVisitCard(
                timeString: _formatVisitDateTime(time),
                name: caregiverName,
                serviceType: serviceType,
                status: status,
                caregiverId: caregiverId,
                onTap: _navigateToVisits,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildVisitCard({
    required String timeString,
    required String name,
    required String serviceType,
    required String status,
    required String? caregiverId,
    required VoidCallback onTap,
  }) {
    Color statusColor;
    String statusLabel;

    switch (status) {
      case 'confirmed':
        statusColor = const Color(0xFF10B981);
        statusLabel = 'CONFIRMED';
        break;
      case 'in_progress':
        statusColor = const Color(0xFF8B5CF6);
        statusLabel = 'IN PROGRESS';
        break;
      case 'completed':
        statusColor = const Color(0xFF0284C7);
        statusLabel = 'COMPLETED';
        break;
      default:
        statusColor = const Color(0xFFF59E0B);
        statusLabel = 'SCHEDULED';
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: statusColor.withValues(alpha: 0.12),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'C',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          timeString,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      serviceType,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade400),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== Posted Jobs & Applicants Preview ====================

  Widget _buildPostedJobsSection() {
    if (_uid == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.work_history_rounded, color: Color(0xFF0F172A), size: 20),
                SizedBox(width: 8),
                Text(
                  'My Care Requests',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: _navigateToJobManagement,
              child: const Text(
                'Manage',
                style: TextStyle(
                  color: Color(0xFF10B981),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('jobs')
              .where('clientId', isEqualTo: _uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SkeletonLoader(height: 70);
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add_task_rounded, color: Color(0xFF10B981)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No active job postings',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            'Post a request to receive bids from nearby caregivers',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _navigateToPostJob,
                      icon: const Icon(Icons.add_circle, color: Color(0xFF10B981)),
                      tooltip: 'Post a Job',
                    ),
                  ],
                ),
              );
            }

            final recentJobs = docs.take(2).toList();
            return Column(
              children: recentJobs.map((doc) {
                final data = doc.data();
                final title = data['title'] ?? 'Untitled Care Job';
                final status = (data['status'] ?? 'open').toString();
                final applicantCount = (data['applicantIds'] as List?)?.length ??
                    (data['bidsCount'] as int? ?? 0);
                final budget = data['budget'] != null ? 'KES ${data['budget']}' : 'Budget open';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.work_outline, color: Color(0xFF3B82F6), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$budget • ${status.toUpperCase()}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (applicantCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$applicantCount Bids',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                        onPressed: _navigateToJobManagement,
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ==================== Recent Messages ====================

  Widget _buildRecentMessagesSection() {
    if (_uid == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF0F172A), size: 20),
                SizedBox(width: 8),
                Text(
                  'Messages',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: _navigateToMessages,
              child: const Text(
                'Open Inbox',
                style: TextStyle(
                  color: Color(0xFF10B981),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('conversations')
              .where('participantIds', arrayContains: _uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SkeletonLoader(height: 70);
            }

            var conversations = snapshot.data?.docs ?? [];
            if (conversations.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.chat_outlined, color: Colors.grey, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No conversation history yet. Start a chat with any caregiver.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              );
            }

            conversations.sort((a, b) {
              final timeA = (a.data()['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime(1970);
              final timeB = (b.data()['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime(1970);
              return timeB.compareTo(timeA);
            });

            final topConvs = conversations.take(2).toList();
            return Column(
              children: topConvs.map((doc) {
                final data = doc.data();
                final participantNames = data['participantNames'] as List<dynamic>? ?? [];
                final lastMessage = data['lastMessage'] as String? ?? 'No message';
                final unreadMap = data['unreadCount'] as Map<dynamic, dynamic>?;
                final unreadCount = (unreadMap?[_uid] as int?) ?? 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ConversationChatScreen(conversationId: doc.id),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.12),
                              child: const Icon(Icons.person, color: Color(0xFF10B981), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    participantNames.join(', '),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    lastMessage,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (unreadCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B82F6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ==================== Care Plans ====================

  Widget _buildCarePlanSection() {
    if (_uid == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.favorite_outline_rounded, color: Color(0xFF0F172A), size: 20),
                SizedBox(width: 8),
                Text(
                  'Care Plan & Routines',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: _navigateToCarePlans,
              child: const Text(
                'View All',
                style: TextStyle(
                  color: Color(0xFF10B981),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _fs.carePlansStream(_uid!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SkeletonLoader(height: 80);
            }

            final carePlans = snapshot.data?.docs ?? [];
            if (carePlans.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.medical_services_outlined, color: Color(0xFF8B5CF6)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No active care plan',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            'Add medication schedules, goals, and doctor notes',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _navigateToCarePlans,
                      child: const Text('+ Add Plan', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF8B5CF6))),
                    ),
                  ],
                ),
              );
            }

            final displayPlans = carePlans.take(2).toList();
            return Column(
              children: displayPlans.map((doc) {
                final plan = doc.data();
                final type = (plan['type'] as String? ?? 'general').toLowerCase();
                final title = plan['title'] ?? 'Care Routine';
                final description = plan['description'] ?? 'No details';

                IconData icon;
                Color color;

                switch (type) {
                  case 'medication':
                    icon = Icons.medication_liquid_rounded;
                    color = const Color(0xFF3B82F6);
                    break;
                  case 'goal':
                    icon = Icons.trending_up_rounded;
                    color = const Color(0xFF10B981);
                    break;
                  case 'appointment':
                    icon = Icons.calendar_today_rounded;
                    color = const Color(0xFFF59E0B);
                    break;
                  case 'exercise':
                    icon = Icons.fitness_center_rounded;
                    color = const Color(0xFF8B5CF6);
                    break;
                  default:
                    icon = Icons.favorite_rounded;
                    color = const Color(0xFFEC4899);
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              description,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ==================== AI Care Companion Card ====================

  Widget _buildAiAssistantSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.smart_toy_rounded, color: Color(0xFF10B981), size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Carelink AI Companion',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Instant care guidance & recommendations',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Need help choosing the right caregiver or drafting requirements?',
            style: TextStyle(fontSize: 12.5, color: Color(0xFFCBD5E1), height: 1.3),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _navigateToAiAssistant,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: const Text(
                    'Ask CareAI Assistant',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== Optional Bottom Navigation ====================

  Widget _buildBottomNavigationBar() {
    return NavigationBar(
      backgroundColor: Colors.white,
      selectedIndex: _currentNavIndex,
      onDestinationSelected: _handleBottomNavTap,
      indicatorColor: const Color(0xFF10B981).withValues(alpha: 0.15),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home, color: Color(0xFF10B981)),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_today_outlined),
          selectedIcon: Icon(Icons.calendar_today, color: Color(0xFF10B981)),
          label: 'Visits',
        ),
        NavigationDestination(
          icon: Icon(Icons.work_outline_rounded),
          selectedIcon: Icon(Icons.work, color: Color(0xFF10B981)),
          label: 'Jobs',
        ),
        NavigationDestination(
          icon: Icon(Icons.chat_bubble_outline_rounded),
          selectedIcon: Icon(Icons.chat_bubble, color: Color(0xFF10B981)),
          label: 'Messages',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person, color: Color(0xFF10B981)),
          label: 'Profile',
        ),
      ],
    );
  }

  void _handleBottomNavTap(int index) {
    if (index == _currentNavIndex && index == 0) return;
    setState(() => _currentNavIndex = index);
    switch (index) {
      case 1:
        _navigateToVisits();
        break;
      case 2:
        _navigateToJobManagement();
        break;
      case 3:
        _navigateToMessages();
        break;
      case 4:
        _navigateToProfile();
        break;
    }
  }

  // ==================== Stream Queries ====================

  Stream<int> _getVisitsToday() {
    if (_uid == null) return Stream.value(0);
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('visits')
        .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((s) => s.docs.length);
  }

  Stream<int> _getActiveJobsCount() {
    if (_uid == null) return Stream.value(0);
    return FirebaseFirestore.instance
        .collection('jobs')
        .where('clientId', isEqualTo: _uid)
        .snapshots()
        .map((s) => s.docs.where((d) {
              final status = (d.data()['status'] ?? '').toString().toLowerCase();
              return status == 'open' || status == 'in_progress' || status == 'active';
            }).length);
  }

  Stream<int> _getUnreadMessagesCount() {
    if (_uid == null) return Stream.value(0);
    return FirebaseFirestore.instance
        .collection('conversations')
        .where('participantIds', arrayContains: _uid)
        .snapshots()
        .map((s) {
      int count = 0;
      for (var d in s.docs) {
        final unreadMap = d.data()['unreadCount'] as Map<dynamic, dynamic>?;
        count += (unreadMap?[_uid] as int?) ?? 0;
      }
      return count;
    });
  }

  Stream<int> _getCarePlansCount() {
    if (_uid == null) return Stream.value(0);
    return _fs.carePlansStream(_uid!).map((s) => s.docs.length);
  }

  // ==================== Navigation Actions ====================

  void _navigateToVisits() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const VisitsScreen()))
        .then((_) => setState(() => _currentNavIndex = 0));
  }

  void _navigateToMessages() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ConversationsInboxScreen()))
        .then((_) => setState(() => _currentNavIndex = 0));
  }

  void _navigateToPaymentHistory() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ClientPaymentHistoryScreen(clientId: _uid)))
        .then((_) => setState(() => _currentNavIndex = 0));
  }

  void _navigateToJobManagement() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientJobManagementScreen()))
        .then((_) => setState(() => _currentNavIndex = 0));
  }

  void _navigateToCaregivers() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchCaregiversScreen()))
        .then((_) => setState(() => _currentNavIndex = 0));
  }

  void _navigateToPostJob() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const PostJobScreen()))
        .then((_) => setState(() => _currentNavIndex = 0));
  }

  void _navigateToCarePlans() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CarePlanScreen()))
        .then((_) => setState(() => _currentNavIndex = 0));
  }

  void _navigateToAiAssistant() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AiAssistantScreen()))
        .then((_) => setState(() => _currentNavIndex = 0));
  }

  Future<void> _navigateToProfile() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ClientProfileEditScreen()));
    if (mounted) setState(() => _currentNavIndex = 0);
  }

  // ==================== Helpers ====================

  String _formatVisitDateTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Date & time unscheduled';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final visitDate = DateTime(date.year, date.month, date.day);
    final timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    final differenceInDays = visitDate.difference(today).inDays;

    if (differenceInDays == 0) {
      return 'Today at $timeStr';
    } else if (differenceInDays == 1) {
      return 'Tomorrow at $timeStr';
    } else if (differenceInDays > 1 && differenceInDays < 7) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${weekdays[date.weekday - 1]} at $timeStr';
    } else {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day} at $timeStr';
    }
  }

  Widget _buildLoginRequiredWidget() {
    return Center(
      child: EmptyStateWidget(
        title: 'Sign In Required',
        message: 'Please sign in to access your client dashboard and care services.',
        icon: Icons.lock_outline_rounded,
        actionLabel: 'Go to Login',
        onActionPressed: () => Navigator.pushReplacementNamed(context, '/login'),
      ),
    );
  }
}
