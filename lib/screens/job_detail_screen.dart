import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class JobDetailScreen extends StatefulWidget {
  final String jobId;
  const JobDetailScreen({super.key, required this.jobId});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  final _fs = FirestoreService();
  final _msgCtrl = TextEditingController();

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Job Detail'), backgroundColor: Colors.green),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _fs.jobStream(widget.jobId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final job = snapshot.data!.data();
                if (job == null) {
                  return const Center(child: Text('Job not found'));
                }
                return Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job['title'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(job['description'] ?? ''),
                      const SizedBox(height: 8),
                      Text('Type: ${job['careType']}'),
                      const SizedBox(height: 8),
                      Text('Status: ${job['status']}'),
                      const Divider(height: 24),
                      const Text('Messages', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _fs.messagesStream(widget.jobId),
                          builder: (context, snap) {
                            if (!snap.hasData) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            final msgs = snap.data!.docs;
                            if (msgs.isEmpty) return const Text('No messages yet');
                            return ListView.builder(
                              itemCount: msgs.length,
                              itemBuilder: (context, index) {
                                final m = msgs[index].data();
                                final isMe = m['senderId'] == uid;
                                final ts = m['timestamp'];
                                final time = ts is Timestamp ? ts.toDate() : null;
                                return Align(
                                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isMe ? Colors.green.shade200 : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(m['text'] ?? ''),
                                        if (time != null)
                                          Text(
                                            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                                            style: const TextStyle(fontSize: 10, color: Colors.black54),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      decoration: const InputDecoration(hintText: 'Type a message', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final text = _msgCtrl.text.trim();
                      if (text.isEmpty || uid == null) return;
                      await _fs.sendMessage(jobId: widget.jobId, senderId: uid, text: text);
                      _msgCtrl.clear();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Icon(Icons.send, color: Colors.white),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
