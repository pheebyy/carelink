import 'package:flutter/material.dart';
import 'package:carelink/screens/caregiverdashboard.dart';
import 'package:carelink/screens/client_dashboard.dart';
import 'package:carelink/screens/conversations_inbox_screen.dart';
import 'package:carelink/screens/notification_sttings_screen.dart';
import 'package:carelink/screens/profile_edit_screen.dart';

class RoleShell extends StatefulWidget {
  final String role; // 'caregiver' or 'client'
  const RoleShell({super.key, required this.role});

  @override
  State<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends State<RoleShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final isCaregiver = widget.role == 'caregiver';

    // Tabs based on role
    final tabs = [
      isCaregiver ?  CaregiverDashboard() :  ClientDashboard(),
      isCaregiver ?  CaregiverJobsScreen() :  ClientJobsScreen(),
      const ConversationsInboxScreen(),
      const _ProfileTab(),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: tabs,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.work_outline),
            selectedIcon: Icon(Icons.work),
            label: 'Jobs',
          ),
          NavigationDestination(
            icon: Icon(Icons.message_outlined),
            selectedIcon: Icon(Icons.message),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
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
        const SizedBox(height: 20),
        const CircleAvatar(
          radius: 40,
          backgroundColor: Colors.green,
          child: Icon(Icons.person, size: 50, color: Colors.white),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            "My Profile",
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 20),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.edit_outlined),
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
            MaterialPageRoute(builder: (_) => NotificationSettingsScreen()),
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.redAccent),
          title: const Text(
            'Logout',
            style: TextStyle(color: Colors.redAccent),
          ),
          onTap: () async {
            // Optional: FirebaseAuth.instance.signOut();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const Scaffold(
                body: Center(child: Text('Logged out successfully.')),
              )),
            );
          },
        ),
      ],
    );
  }
}

class CaregiverJobsScreen extends StatelessWidget {
  const CaregiverJobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text("Caregiver Jobs", style: TextStyle(fontSize: 18)),
      ),
    );
  }
}

class ClientJobsScreen extends StatelessWidget {
  const ClientJobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text("Available Caregivers / Requests", style: TextStyle(fontSize: 18)),
      ),
    );
  }
}
