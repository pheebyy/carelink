import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/message_model.dart';

class ConversationChatScreen extends StatefulWidget {
  final String conversationId;
  const ConversationChatScreen({super.key, required this.conversationId});

  @override
  State<ConversationChatScreen> createState() => _ConversationChatScreenState();
}

class _ConversationChatScreenState extends State<ConversationChatScreen> {
  final _msgCtrl = TextEditingController();

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    final ref = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages');

    final message = ChatMessage(
      id: '',
      senderId: uid,
      text: text,
      timestamp: Timestamp.now(),
      read: true,
    );

    final messageMap = message.toMap();
    messageMap['readBy'] = [uid];

    await ref.add(messageMap);

    // update conversation metadata
    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .set({
      'lastMessage': text,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _msgCtrl.clear();
  }

  Future<void> _markRead(QuerySnapshot<Map<String, dynamic>> snap) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final batch = FirebaseFirestore.instance.batch();

    for (final doc in snap.docs) {
      final data = doc.data();
      final List<dynamic>? readBy = data['readBy'] as List<dynamic>?;
      if (readBy == null || !readBy.contains(uid)) {
        batch.update(doc.reference, {
          'readBy': FieldValue.arrayUnion([uid])
        });
      }
    }

    await batch.commit();

    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .set({
      'unreadCounts': {uid: 0}
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final messagesStream = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages')
        .orderBy('timestamp')
        .limit(100)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Chat'), backgroundColor: Colors.green),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: messagesStream,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                _markRead(snap.data!);

                final uid = FirebaseAuth.instance.currentUser!.uid;
                final messages = snap.data!.docs
                    .map((doc) => ChatMessage.fromDoc(doc))
                    .toList();

                return ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final m = messages[i];
                    final isMe = m.senderId == uid;
                    final time = m.timestamp?.toDate();
                    final isRead = m.read == true;

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.green.shade200
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.text),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (time != null)
                                  Text(
                                    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.black54),
                                  ),
                                const SizedBox(width: 6),
                                Icon(
                                  isRead ? Icons.done_all : Icons.check,
                                  size: 14,
                                  color: Colors.black54,
                                ),
                              ],
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
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Type a message',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _send,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Icon(Icons.send, color: Colors.white),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
