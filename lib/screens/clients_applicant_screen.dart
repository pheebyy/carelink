import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class ClientApplicantsScreen extends StatelessWidget {
  final String jobId;
  const ClientApplicantsScreen({super.key, required this.jobId});

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('jobs')
        .doc(jobId)
        .collection('applications')
        .orderBy('createdAt', descending: true)
        .snapshots();
    final fs = FirestoreService();

    return Scaffold(
      appBar: AppBar(title: const Text('Applicants'), backgroundColor: Colors.green),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No applications yet'));
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final caregiverId = d['caregiverId'] ?? '';
              final status = d['status'] ?? 'applied';
              return ListTile(
                title: Text('Caregiver: $caregiverId'),
                subtitle: Text('Status: $status'),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'shortlist') {
                      await fs.updateApplicationStatus(jobId, docs[i].id, 'shortlisted');
                    } else if (value == 'hire') {
                      await fs.hireCaregiver(jobId, caregiverId);
                      await fs.updateApplicationStatus(jobId, docs[i].id, 'hired');
                    }
                  },
                  itemBuilder: (c) => const [
                    PopupMenuItem(value: 'shortlist', child: Text('Shortlist')),
                    PopupMenuItem(value: 'hire', child: Text('Hire')),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
