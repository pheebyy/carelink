import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ConversationsInboxScreen extends StatelessWidget {
  const ConversationsInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final stream = FirebaseFirestore.instance
        .collection('conversations')
        .where('participants', arrayContains: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No conversations yet'));
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final d = docs[index].data();
            final unread = (d['unreadCounts']?[uid] ?? 0) as int;
            final subtitle = d['lastMessage'] ?? '';
            return ListTile(
              title: Text(d['title'] ?? 'Chat'),
              subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: unread > 0
                  ? CircleAvatar(radius: 12, backgroundColor: Colors.green, child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 12)))
                  : null,
              onTap: () {
                Navigator.pushNamed(context, '/conversation', arguments: {'conversationId': docs[index].id});
              },
            );
          },
        );
      },
    );
  }
}
