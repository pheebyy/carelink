import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("CareLink"),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting section
            Text(
              "Welcome, ${user?.email ?? 'Guest'} 👋",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "What would you like to do today?",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),

            // Action cards
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildFeatureCard(
                    icon: Icons.search,
                    title: "Find a Caregiver",
                    color: Colors.green.shade100,
                    onTap: () {
                      // TODO: Navigate to caregiver list screen
                    },
                  ),
                  _buildFeatureCard(
                    icon: Icons.assignment_ind,
                    title: "Find a Job",
                    color: Colors.orange.shade100,
                    onTap: () {
                      // TODO: Navigate to caregiving job list
                    },
                  ),
                  _buildFeatureCard(
                    icon: Icons.favorite,
                    title: "My Favorites",
                    color: Colors.pink.shade100,
                    onTap: () {
                      // TODO: Navigate to favorites screen
                    },
                  ),
                  _buildFeatureCard(
                    icon: Icons.person,
                    title: "Profile",
                    color: Colors.blue.shade100,
                    onTap: () {
                      // TODO: Navigate to profile page
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: color,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Colors.green.shade800),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
