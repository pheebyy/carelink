import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import 'job_detail_screen.dart';
import 'post_job_screen.dart';

class ClientDashboard extends StatelessWidget {
  ClientDashboard({super.key});
  final _fs = FirestoreService();
  final _uid = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Client Dashboard'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PostJobScreen()),
              );
            },
            icon: const Icon(Icons.add),
            tooltip: 'Post Job',
          )
        ],
      ),
      body: _uid == null
          ? const Center(child: Text('Please login again'))
          : StreamBuilder(
              stream: _fs.clientJobsStream(_uid!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData) {
                  return const Center(child: Text('No jobs'));
                }
                final docs = (snapshot.data as dynamic).docs as List;
                if (docs.isEmpty) {
                  return const Center(child: Text('No jobs yet. Tap + to post.'));
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final d = docs[index].data();
                    final jobId = docs[index].id;
                    return ListTile(
                      title: Text(d['title'] ?? ''),
                      subtitle: Text('${d['careType']} • ${d['status']}'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => JobDetailScreen(jobId: jobId),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
