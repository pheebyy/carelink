import 'package:carelink/screens/job_detail_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class CaregiverDashboard extends StatelessWidget {
  CaregiverDashboard({super.key});
  final _fs = FirestoreService();
  final _uid = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Caregiver Dashboard'),
        backgroundColor: Colors.green,
      ),
      body: StreamBuilder(
        stream: _fs.openJobsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('No jobs available'));
          }

          final docs = (snapshot.data as dynamic).docs as List;
          if (docs.isEmpty) {
            return const Center(child: Text('No open jobs found'));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final d = docs[index].data();
              final jobId = docs[index].id;
              return ListTile(
                title: Text(d['title'] ?? ''),
                subtitle: Text(d['description'] ?? ''),
                trailing: ElevatedButton(
                  onPressed: _uid == null
                      ? null
                      : () async {
                          await _fs.applyToJob(jobId, _uid!);
                          await _fs.createApplication(jobId, _uid!);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Applied to job')),
                          );
                        },
                  child: const Text('Apply'),
                ),
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
