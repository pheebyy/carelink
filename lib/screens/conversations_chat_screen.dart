import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../Models/message_model.dart';

class ConversationChatScreen extends StatefulWidget {
  final String conversationId;
  const ConversationChatScreen({super.key, required this.conversationId});

  @override
  State<ConversationChatScreen> createState() => _ConversationChatScreenState();
}

class _ConversationChatScreenState extends State<ConversationChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final displayName = FirebaseAuth.instance.currentUser?.displayName ?? 'User';
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    final ref = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages');

    final message = ChatMessage(
      id: '', // Will be set by Firestore
      senderId: uid,
      senderName: displayName,
      text: text,
      timestamp: Timestamp.now(),
      read: false,
      readBy: [uid],
    );

    await ref.add(message.toMap());

    // Update conversation metadata
    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .set({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _msgCtrl.clear();
    _scrollToBottom();
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

    // Update unread count
    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .set({
      'unreadCount': {uid: 0}
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final messagesStream = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Chat',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Call feature coming soon')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.video_call_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Video call feature coming soon')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: messagesStream,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.green),
                  );
                }

                _markRead(snap.data!);

                final messages = snap.data!.docs
                    .map((doc) => ChatMessage.fromDoc(doc))
                    .toList();

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.mail_outline, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet\nStart the conversation!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final m = messages[i];
                    final isMe = m.senderId == uid;
                    final time = m.timestamp?.toDate();
                    final isRead = m.readBy.length > 1;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment:
                              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            if (!isMe)
                              Padding(
                                padding: const EdgeInsets.only(left: 8, bottom: 4),
                                child: Text(
                                  m.senderName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            Container(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.75,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isMe ? Colors.green : Colors.white,
                                borderRadius: BorderRadius.circular(16).copyWith(
                                  bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.text,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isMe ? Colors.white : Colors.black87,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (time != null)
                                        Text(
                                          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isMe ? Colors.white70 : Colors.grey.shade600,
                                          ),
                                        ),
                                      if (isMe) ...[
                                        const SizedBox(width: 4),
                                        Icon(
                                          isRead ? Icons.done_all : Icons.check,
                                          size: 14,
                                          color: Colors.white70,
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
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

          // Input area
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.add_rounded, color: Colors.green.shade700),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Attachment feature coming soon')),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _msgCtrl,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    onPressed: _send,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

