import 'package:carelink/screens/caregiverdashboard.dart';
import 'package:carelink/screens/notification_sttings_screen.dart';
import 'package:flutter/material.dart';
import 'client_dashboard.dart';
import 'conversations_inbox_screen.dart';
import 'profile_edit_screen.dart';


class RoleShell extends StatefulWidget {
  final String role; // 'caregiver' | 'client'
  const RoleShell({super.key, required this.role});

  @override
  State<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends State<RoleShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final isCaregiver = widget.role == 'caregiver';
    final tabs = [
      isCaregiver ? CaregiverDashboard() : ClientDashboard(),
      // Jobs tab - reuse dashboards for MVP (could split to dedicated lists later)
      isCaregiver ? CaregiverDashboard() : ClientDashboard(),
      const ConversationsInboxScreen(),
      const _ProfileTab(),
    ];

    return Scaffold(
      body: SafeArea(child: tabs[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.work_outline), selectedIcon: Icon(Icons.work), label: 'Jobs'),
          NavigationDestination(icon: Icon(Icons.message_outlined), selectedIcon: Icon(Icons.message), label: 'Messages'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.edit),
          title: const Text('Edit Profile'),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.notifications_active_outlined),
          title: const Text('Notification Settings'),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) =>  NotificationSettingsScreen()),
          ),
        ),
      ],
    );
  }
}
