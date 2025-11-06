import 'package:carelink/screens/ClientProfileEditScreen.dart';
import 'package:carelink/screens/ai_assistant_screen.dart';
import 'package:carelink/screens/conversations_chat_screen.dart';
import 'package:carelink/screens/conversations_inbox_screen.dart';
import 'package:carelink/screens/visits_screen.dart';
import 'package:carelink/screens/search_caregivers_screen.dart';
import 'package:carelink/screens/post_job_screen.dart';
import 'package:carelink/screens/client_payment_screen.dart';
import 'package:carelink/screens/care_plan_screen.dart';
import 'package:carelink/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ClientDashboard extends StatefulWidget {
  const ClientDashboard({super.key});

  @override
  State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard> {
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  final _userName = FirebaseAuth.instance.currentUser?.displayName ?? 'User';
  final _fs = FirestoreService();
  int _currentNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _buildAppBar(),
      body: _uid == null
          ? _buildLoginRequiredWidget()
          : RefreshIndicator(
              onRefresh: _refreshDashboard,
              color: Colors.green,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatsSection(),
                      const SizedBox(height: 24),
                      _buildUpcomingVisitsSection(),
                      const SizedBox(height: 20),
                      _buildQuickActionsSection(),
                      const SizedBox(height: 24),
                      _buildMessagesSection(),
                      const SizedBox(height: 24),
                      _buildCarePlanSection(),
                      const SizedBox(height: 24),
                      _buildAiAssistantCard(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Future<void> _refreshDashboard() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) setState(() {});
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: isError ? Colors.red.shade600 : Colors.grey.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ==================== Build Methods ====================
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.menu, color: Colors.grey.shade800),
        onPressed: () => _showSnackBar('Menu coming soon'),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Client Home',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Text(
            'Welcome back, $_userName',
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
          icon: Icon(Icons.notifications_outlined, color: Colors.grey.shade800),
          onPressed: () => _showSnackBar('Notifications coming soon'),
        ),
      ],
    );
  }

  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Summary',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildDynamicStatCard(
                icon: Icons.calendar_today,
                label: 'Today',
                color: Colors.blue,
                query: _getVisitsToday(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDynamicStatCard(
                icon: Icons.mail_outline,
                label: 'Messages',
                color: Colors.purple,
                query: _getUnreadMessagesCount(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDynamicStatCard(
                icon: Icons.paid_outlined,
                label: 'Payments',
                color: Colors.orange,
                query: _getPendingPaymentsCount(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUpcomingVisitsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.event, color: Colors.grey.shade800, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Upcoming Visits',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () => _navigateToVisits(),
              child: Text(
                'See all',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildUpcomingVisits(),
      ],
    );
  }

  Widget _buildUpcomingVisits() {
    if (_uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('visits')
          .where('status', isEqualTo: 'upcoming')

          .snapshots(),
      builder: (context, snapshot) {
        debugPrint('Visits snapshot state: ${snapshot.connectionState}');
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState('Loading visits...');
        }

        if (snapshot.hasError) {
          debugPrint('Visits snapshot error: ${snapshot.error}');
          // Try alternative collection path
          return _buildAlternativeVisitsView();
        }

        var visits = snapshot.data?.docs ?? [];
        debugPrint('Loaded ${visits.length} upcoming visits');

        // Sort by dateTime in Dart (since we can't use orderBy with where clause)
        visits.sort((a, b) {
          final timeA = (a['dateTime'] as Timestamp?)?.toDate() ?? DateTime(2099);
          final timeB = (b['dateTime'] as Timestamp?)?.toDate() ?? DateTime(2099);
          return timeA.compareTo(timeB); // Ascending order (earliest first)
        });

        // Take only first 2
        visits = visits.take(2).toList();

        if (visits.isEmpty) {
          return _buildEmptyState(
            icon: Icons.event_available,
            title: 'No Upcoming Visits',
            message: 'Your schedule is clear',
          );
        }

        return Column(
          children: visits.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final time = data['dateTime'] as Timestamp?;
            final caregiverName = data['caregiverName'] ?? 'Caregiver';
            final serviceType = data['serviceType'] ?? 'Care Visit';
            final status = data['status'] ?? 'scheduled';

            final statusColor =
                status == 'confirmed' ? Colors.green : Colors.blue;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildVisitItem(
                time: _formatTime(time),
                name: caregiverName,
                type: serviceType,
                status: status,
                statusColor: statusColor,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildAlternativeVisitsView() {
    return _buildErrorState(
      icon: Icons.event_busy,
      title: 'Unable to load visits',
      message: 'Check your Firestore collection permissions',
      onRetry: () => setState(() {}),
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _showConfirmAvailabilityDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            icon: const Icon(Icons.check_circle, color: Colors.white, size: 22),
            label: const Text(
              'Confirm Availability',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _navigateToCaregivers,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.blue, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.search, color: Colors.blue, size: 20),
                  label: const Text(
                    'Find Caregivers',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _navigateToPostJob,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.add_circle, color: Colors.white, size: 20),
                  label: const Text(
                    'Post a Job',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMessagesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.message, color: Colors.grey.shade800, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Messages',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: _navigateToMessages,
              child: Text(
                'Open',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildMessagesList(),
      ],
    );
  }

  Widget _buildMessagesList() {
    if (_uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .where('participantIds', arrayContains: _uid)
          // Note: Removed orderBy - requires composite index with arrayContains
          // Instead, sorting is done in Dart below
          .snapshots(),
      builder: (context, snapshot) {
        debugPrint('Messages snapshot state: ${snapshot.connectionState}');
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState('Loading messages...');
        }

        if (snapshot.hasError) {
          debugPrint('Messages snapshot error: ${snapshot.error}');
          return _buildErrorState(
            icon: Icons.mail_outline,
            title: 'Unable to load messages',
            message: 'Check your connection or Firestore permissions',
            onRetry: () => setState(() {}),
          );
        }

        var conversations = snapshot.data?.docs ?? [];
        debugPrint('Loaded ${conversations.length} conversations');

        // Sort by lastMessageTime in Dart (since we can't use orderBy with arrayContains)
        conversations.sort((a, b) {
          final timeA = (a['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime(1970);
          final timeB = (b['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime(1970);
          return timeB.compareTo(timeA); // Descending order
        });

        // Take only first 3
        conversations = conversations.take(3).toList();

        if (conversations.isEmpty) {
          return _buildEmptyState(
            icon: Icons.mail_outline,
            title: 'No Messages',
            message: 'Your conversations will appear here',
          );
        }

        return Column(
          children: conversations.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final participantNames =
                data['participantNames'] as List<dynamic>? ?? [];
            final lastMessage = data['lastMessage'] as String? ?? '';
            final unreadCount = (data['unreadCount'] as Map?)?[_uid] ?? 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildMessageItem(
                conversationId: doc.id,
                names: participantNames.join(', '),
                message: lastMessage,
                unreadCount: unreadCount as int,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildCarePlanSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.favorite, color: Colors.grey.shade800, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Care Plan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CarePlanScreen()),
                );
              },
              child: Text(
                'View All',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _fs.carePlansStream(_uid!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final carePlans = snapshot.data?.docs ?? [];

            if (carePlans.isEmpty) {
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CarePlanScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_outline, color: Colors.grey.shade400),
                      const SizedBox(width: 8),
                      Text(
                        'Add your first care plan',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Show first 2 care plans
            final displayPlans = carePlans.take(2).toList();

            return Column(
              children: displayPlans.map((doc) {
                final plan = doc.data();
                final type = plan['type'] ?? 'general';
                final title = plan['title'] ?? 'Untitled';
                final description = plan['description'] ?? '';

                IconData icon;
                Color color;

                switch (type) {
                  case 'medication':
                    icon = Icons.medication;
                    color = Colors.blue;
                    break;
                  case 'goal':
                    icon = Icons.trending_up;
                    color = Colors.green;
                    break;
                  case 'appointment':
                    icon = Icons.calendar_today;
                    color = Colors.orange;
                    break;
                  case 'exercise':
                    icon = Icons.fitness_center;
                    color = Colors.purple;
                    break;
                  default:
                    icon = Icons.favorite;
                    color = Colors.pink;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildCarePlanItem(
                    icon: icon,
                    title: title,
                    description: description,
                    color: color,
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAiAssistantCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AiAssistantScreen()),
        ).then((_) => setState(() => _currentNavIndex = 0));
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade100, Colors.cyan.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.blue.shade300, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade600,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.help_outline, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ask your assistant',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.blue.shade900,
                    ),
                  ),
                  Text(
                    'About care, visits, or payments...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade800,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AiAssistantScreen()),
                  );
                },
                icon: const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ),
          ],
        ),
      ),
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
      onTap: (index) => _navigateToPage(index),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), label: 'Visits'),
        BottomNavigationBarItem(icon: Icon(Icons.chat_outlined), label: 'Messages'),
        BottomNavigationBarItem(icon: Icon(Icons.wallet_giftcard_outlined), label: 'Payments'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outlined), label: 'Profile'),
      ],
    );
  }

  // ==================== Component Builders ====================
  Widget _buildLoadingState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.green),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState({
    required IconData icon,
    required String title,
    required String message,
    required VoidCallback onRetry,
  }) {
    // Safely truncate error message
    String displayMessage = message;
    if (message.contains(':')) {
      // Extract the meaningful part of Firebase error
      displayMessage = message.split(':').last.trim();
    }
    if (displayMessage.length > 50) {
      displayMessage = '${displayMessage.substring(0, 50)}...';
    }
    if (displayMessage.isEmpty) {
      displayMessage = 'Please try again';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.red.shade600, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  displayMessage,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(
            height: 32,
            width: 32,
            child: IconButton.filled(
              onPressed: onRetry,
              style: IconButton.styleFrom(backgroundColor: Colors.red.shade100),
              icon: Icon(Icons.refresh, color: Colors.red.shade600, size: 18),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicStatCard({
    required IconData icon,
    required String label,
    required Color color,
    required Stream<int> query,
  }) {
    return StreamBuilder<int>(
      stream: query,
      builder: (context, snapshot) {
        final value = snapshot.data ?? 0;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (isLoading)
                SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              else
                Text(
                  value.toString(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVisitItem({
    required String time,
    required String name,
    required String type,
    required String status,
    required Color statusColor,
  }) {
    return Container(
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
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.person, color: Colors.green.shade600, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'With: $name',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  type,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarePlanItem({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 22),
        ],
      ),
    );
  }

  Widget _buildMessageItem({
    required String conversationId,
    required String names,
    required String message,
    required int unreadCount,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConversationChatScreen(conversationId: conversationId),
          ),
        ).then((_) => setState(() => _currentNavIndex = 0));
      },
      child: Container(
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
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.people, color: Colors.green.shade600, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    names,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==================== Navigation Methods ====================
  void _navigateToPage(int index) {
    if (index == _currentNavIndex && index == 0) return;

    setState(() => _currentNavIndex = index);

    switch (index) {
      case 0:
        break;
      case 1:
        _navigateToVisits();
        break;
      case 2:
        _navigateToMessages();
        break;
      case 3:
        _navigateToPayments();
        break;
      case 4:
        _navigateToProfile();
        break;
    }
  }

  void _navigateToVisits() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VisitsScreen()),
    ).then((_) => setState(() => _currentNavIndex = 0));
  }

  void _navigateToMessages() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConversationsInboxScreen()),
    ).then((_) => setState(() => _currentNavIndex = 0));
  }

  void _navigateToPayments() {
    _showPaymentOptionsSheet();
  }

  void _navigateToCaregivers() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SearchCaregiversScreen()),
    ).then((_) => setState(() => _currentNavIndex = 0));
  }

  void _navigateToPostJob() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PostJobScreen()),
    ).then((_) => setState(() => _currentNavIndex = 0));
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ClientProfileEditScreen()),
    ).then((_) => setState(() => _currentNavIndex = 0));
  }

  void _showPaymentOptionsSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildPaymentOptionsSheet(),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }

  Widget _buildPaymentOptionsSheet() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Make Payment',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _buildPaymentsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentsList() {
    if (_uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .where('clientId', isEqualTo: _uid)
          .where('status', isEqualTo: 'assigned')
          // Note: Removed orderBy - requires composite index with two where clauses
          // Instead, sorting is done in Dart below
          .snapshots(),
      builder: (context, snapshot) {
        debugPrint('Payments snapshot state: ${snapshot.connectionState}');
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState('Loading payments...');
        }

        if (snapshot.hasError) {
          debugPrint('Payments snapshot error: ${snapshot.error}');
          return _buildErrorState(
            icon: Icons.payment_outlined,
            title: 'Unable to load payments',
            message: 'Check your connection or Firestore permissions',
            onRetry: () => setState(() {}),
          );
        }

        var jobs = snapshot.data?.docs ?? [];
        debugPrint('Loaded ${jobs.length} payment jobs');

        // Sort by createdAt in Dart
        jobs.sort((a, b) {
          final dateA = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
          final dateB = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
          return dateB.compareTo(dateA); // Descending order
        });

        if (jobs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.payment_outlined,
            title: 'No Active Assignments',
            message: 'Assign a caregiver to make payments',
          );
        }

        return ListView.builder(
          itemCount: jobs.length,
          itemBuilder: (context, index) {
            final job = jobs[index].data() as Map<String, dynamic>;
            final caregiverId = job['assignedCaregiverId'] ?? '';
            final caregiverName = job['assignedCaregiverName'] ?? 'Unknown';
            final jobTitle = job['title'] ?? 'Job';

            return GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClientPaymentScreen(
                      caregiverId: caregiverId,
                      caregiverName: caregiverName,
                    ),
                  ),
                ).then((_) => setState(() => _currentNavIndex = 0));
              },
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
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          caregiverName.isNotEmpty
                              ? caregiverName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: Colors.green.shade600,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            caregiverName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            jobTitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==================== Stream Queries ====================
  Stream<int> _getVisitsToday() {
    if (_uid == null) return Stream.value(0);

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      return FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('visits')
          .where('dateTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .snapshots()
          .map((snapshot) => snapshot.docs.length)
          .handleError((error) {
        debugPrint('Error getting visits: $error');
        return 0;
      });
    } catch (e) {
      debugPrint('Error in _getVisitsToday: $e');
      return Stream.value(0);
    }
  }

  Stream<int> _getUnreadMessagesCount() {
    if (_uid == null) return Stream.value(0);

    try {
      return FirebaseFirestore.instance
          .collection('conversations')
          .where('participantIds', arrayContains: _uid)
          .snapshots()
          .map((snapshot) {
            int totalUnread = 0;
            for (var doc in snapshot.docs) {
              try {
                final data = doc.data();
                final unreadMap = data['unreadCount'] as Map<dynamic, dynamic>?;
                if (unreadMap != null && unreadMap.containsKey(_uid)) {
                  totalUnread += (unreadMap[_uid] ?? 0) as int;
                }
              } catch (e) {
                debugPrint('Error processing conversation: $e');
              }
            }
            return totalUnread;
          })
          .handleError((error) {
            debugPrint('Error getting unread messages: $error');
            return 0;
          });
    } catch (e) {
      debugPrint('Error in _getUnreadMessagesCount: $e');
      return Stream.value(0);
    }
  }

  Stream<int> _getPendingPaymentsCount() {
    if (_uid == null) return Stream.value(0);

    try {
      return FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('payments')
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .map((snapshot) => snapshot.docs.length)
          .handleError((error) {
            debugPrint('Error getting pending payments: $error');
            return 0;
          });
    } catch (e) {
      debugPrint('Error in _getPendingPaymentsCount: $e');
      return Stream.value(0);
    }
  }

  // ==================== Utility Methods ====================
  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Time not set';

    try {
      final dateTime = timestamp.toDate();
      final now = DateTime.now();
      final difference = dateTime.difference(now);

      if (difference.inDays == 0) {
        return 'Today • ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays == 1) {
        return 'Tomorrow • ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year} • ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      debugPrint('Error formatting time: $e');
      return 'Invalid date';
    }
  }

  void _showConfirmAvailabilityDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Availability'),
        content: const Text('Are you available for upcoming visits?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showSnackBar('Availability confirmed');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginRequiredWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.login, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('Please login again'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }
}