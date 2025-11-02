import 'package:carelink/screens/ClientProfileEditScreen.dart';
import 'package:carelink/screens/ai_assistant_screen.dart';
import 'package:carelink/screens/conversations_chat_screen.dart';
import 'package:carelink/screens/conversations_inbox_screen.dart';
import 'package:carelink/screens/visits_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';


class ClientDashboard extends StatefulWidget {
  const ClientDashboard({super.key});

  @override
  State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard> {
  final _fs = FirestoreService();
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  final _userName = FirebaseAuth.instance.currentUser?.displayName ?? 'User';
  int _currentNavIndex = 0;

  void _navigateToPage(int index) {
    if (index == _currentNavIndex && index == 0) {
      return; // Stay on dashboard if already there
    }

    switch (index) {
      case 0:
        // Dashboard - stay here
        setState(() => _currentNavIndex = 0);
        break;
      case 1:
        // Navigate to Visits page
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const VisitsScreen()),
        ).then((_) {
          // Reset index when returning
          setState(() => _currentNavIndex = 0);
        });
        break;
      case 2:
        // Navigate to Messages page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>  ConversationsInboxScreen(),
          ),
        ).then((_) {
          setState(() => _currentNavIndex = 0);
        });
        break;
      case 3:
        // Navigate to Payments page
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payments feature coming soon')),
        );
        setState(() => _currentNavIndex = 0);
        break;
      case 4:
        // Navigate to Profile page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClientProfileEditScreen(),
          ),
        ).then((_) {
          setState(() => _currentNavIndex = 0);
        });
        break;
    }
  }

  Future<void> _refreshDashboard() async {
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 400));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.menu, color: Colors.grey.shade800),
          onPressed: () {},
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Client Home',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
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
            onPressed: () {},
          ),
        ],
      ),
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
                      // Stats section
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
                      const SizedBox(height: 24),

                      // Upcoming Visits section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.arrow_forward,
                                  color: Colors.grey.shade800, size: 20),
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
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const VisitsScreen(),
                                ),
                              ).then((_) {
                                setState(() => _currentNavIndex = 0);
                              });
                            },
                            child: Text(
                              'See all',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Upcoming visits list
                      _buildUpcomingVisits(),
                      const SizedBox(height: 20),

                      // Confirm Availability button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            _showConfirmAvailabilityDialog();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Confirm Availability',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Messages section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.chat_outlined,
                                  color: Colors.grey.shade800, size: 20),
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
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const ConversationChatScreen(
                                          conversationId: ''),
                                ),
                              ).then((_) {
                                setState(() => _currentNavIndex = 0);
                              });
                            },
                            child: Text(
                              'Open',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Messages list from Firestore
                      _buildMessagesList(),
                      const SizedBox(height: 20),

                      // Care Plan section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.favorite,
                                  color: Colors.grey.shade800, size: 20),
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Care plan view opening'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                            child: Text(
                              'View',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Care plan items
                      _buildCarePlanItem(
                        icon: Icons.calendar_today,
                        title: 'Daily',
                        description: 'Medication at 9:00 AM and 9:00 PM',
                      ),
                      const SizedBox(height: 10),
                      _buildCarePlanItem(
                        icon: Icons.trending_up,
                        title: 'Goal',
                        description: 'Increase mobility • Week 3',
                      ),
                      const SizedBox(height: 16),

                      // Chat prompt section
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AiAssistantScreen(),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.help_outline,
                                  color: Colors.blue.shade600, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Ask your assistant about care,',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      'visits, or payments...',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Try: "When is my next visit?"',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentNavIndex,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey.shade600,
        elevation: 8,
        onTap: (index) {
          _navigateToPage(index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            label: 'Visits',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_outlined),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.wallet_giftcard_outlined),
            label: 'Payments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outlined),
            label: 'Profile',
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Go Back'),
          )
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_uid == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .where('participantIds', arrayContains: _uid)
          .orderBy('lastMessageTime', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: CircularProgressIndicator(color: Colors.green),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Error loading messages',
              style: TextStyle(color: Colors.red.shade600),
            ),
          );
        }

        final conversations = snapshot.data?.docs ?? [];

        if (conversations.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No messages yet',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          );
        }

        return Column(
          children: conversations.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final participantNames =
                data['participantNames'] as List<dynamic>? ?? [];
            final lastMessage = data['lastMessage'] as String? ?? '';
            final lastMessageTime = data['lastMessageTime'] as Timestamp?;
            final unreadCount = (data['unreadCount'] as Map?)?[_uid] ?? 0;

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ConversationChatScreen(
                      conversationId: doc.id,
                    ),
                  ),
                ).then((_) {
                  setState(() => _currentNavIndex = 0);
                });
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
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
                      child: Icon(
                        Icons.people,
                        color: Colors.green.shade600,
                        size: 24,
                      ),
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
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            lastMessage,
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
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
          }).toList(),
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
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
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingVisits() {
    if (_uid == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('visits')
          .where('status', isEqualTo: 'upcoming')
          .orderBy('dateTime')
          .limit(2)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: CircularProgressIndicator(color: Colors.green),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Error loading visits',
              style: TextStyle(color: Colors.red.shade600),
            ),
          );
        }

        final visits = snapshot.data?.docs ?? [];

        if (visits.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No upcoming visits',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          );
        }

        return Column(
          children: visits.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final time = data['dateTime'] as Timestamp?;
            final caregiverName = data['caregiverName'] ?? 'Caregiver';
            final serviceType = data['serviceType'] ?? 'Care Visit';
            final status = data['status'] ?? 'scheduled';

            final statusColor = status == 'confirmed' ? Colors.green : Colors.blue;

            return Column(
              children: [
                _buildVisitItem(
                  time: _formatTime(time),
                  name: caregiverName,
                  type: serviceType,
                  status: status,
                  statusColor: statusColor,
                ),
                if (visits.indexOf(doc) < visits.length - 1)
                  const SizedBox(height: 10),
              ],
            );
          }).toList(),
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
            child: Icon(
              Icons.person,
              color: Colors.green.shade600,
              size: 24,
            ),
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
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
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
          Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
        ],
      ),
    );
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Time not set';

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
        final hasError = snapshot.hasError;

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
              else if (hasError)
                Text(
                  '—',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                )
              else
                Text(
                  value.toString(),
                  style: TextStyle(
                    fontSize: 18,
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

  Stream<int> _getVisitsToday() {
    if (_uid == null) {
      return Stream.value(0);
    }

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
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<int> _getUnreadMessagesCount() {
    if (_uid == null) {
      return Stream.value(0);
    }

    return FirebaseFirestore.instance
        .collection('conversations')
        .where('participantIds', arrayContains: _uid)
        .snapshots()
        .map((snapshot) {
      int totalUnread = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final unreadCount = (data['unreadCount'] as Map?)?[_uid] ?? 0;
        totalUnread += unreadCount as int;
      }
      return totalUnread;
    });
  }

  Stream<int> _getPendingPaymentsCount() {
    if (_uid == null) {
      return Stream.value(0);
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('payments')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Availability confirmed'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}