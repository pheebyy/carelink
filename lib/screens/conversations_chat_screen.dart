import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
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
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _callSub;
  String? _activeIncomingCallId;

  @override
  void initState() {
    super.initState();
    _listenForIncomingCalls();
    _ensureTokenSaved();
  }

  void _ensureTokenSaved() async {
    await NotificationService.instance.ensureUserTokenSaved();
  }

  void dispose() {
    _callSub?.cancel();
    _msgCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _listenForIncomingCalls() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _callSub = FirebaseFirestore.instance
        .collection('calls')
        .where('conversationId', isEqualTo: widget.conversationId)
        .snapshots()
        .listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;
          final callerId = data['callerId'] as String?;
          final offer = data['offer'];
          final callId = change.doc.id;

          // If this user is not the caller and there's an offer, show incoming
          if (callerId != uid && offer != null && _activeIncomingCallId != callId) {
            _activeIncomingCallId = callId;
            // show dialog
            if (mounted) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => AlertDialog(
                  title: const Text('Incoming call'),
                  content: Text('${data['callerDisplayName'] ?? 'Caller'} is calling'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        // optionally delete or mark declined later
                      },
                      child: const Text('Decline'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _startVideoCall();
                      },
                      child: const Text('Answer (Jitsi)'),
                    ),
                  ],
                ),
              );
            }
          }
        }
      }
    });
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
            onPressed: () => _startVoiceCall(),
          ),
          IconButton(
            icon: const Icon(Icons.video_call_outlined),
            onPressed: () => _showVideoCallOptions(),
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

  Future<void> _startVoiceCall() async {
    try {
      final currentUid = FirebaseAuth.instance.currentUser!.uid;
      final conv = await FirestoreService().getConversation(widget.conversationId);
      final data = conv.data();
      if (data == null) throw Exception('Conversation not found');

      final List<dynamic> ids = data['participantIds'] ?? [];
      final otherId = ids.cast<String?>().firstWhere((id) => id != currentUid, orElse: () => null);
      if (otherId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No recipient found')));
        return;
      }

      final userDoc = await FirestoreService().getUser(otherId);
      final phone = userDoc.data()?['phone'] as String?;
      if (phone == null || phone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recipient has no phone number')));
        return;
      }

      final uri = Uri(scheme: 'tel', path: phone);
      if (!await canLaunchUrl(uri)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot place call on this device')));
        return;
      }

      await launchUrl(uri);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Call failed: $e')));
    }
  }

  Future<void> _startVideoCall() async {
    try {
      final currentUid = FirebaseAuth.instance.currentUser!.uid;
      final conv = await FirestoreService().getConversation(widget.conversationId);
      final data = conv.data();
      if (data == null) throw Exception('Conversation not found');

      final List<dynamic> ids = data['participantIds'] ?? [];
      final otherId = ids.cast<String?>().firstWhere((id) => id != currentUid, orElse: () => null);
      if (otherId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No recipient found')));
        return;
      }

      final roomName = 'carelink_${widget.conversationId}';
      final jitsiUrl = 'https://meet.jitsi.org/$roomName';

      if (await canLaunchUrl(Uri.parse(jitsiUrl))) {
        await launchUrl(Uri.parse(jitsiUrl), mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch video call')));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Video call failed: $e')));
    }
  }

  void _showVideoCallOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.videocam),
                title: const Text('Jitsi (via browser)'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _startVideoCall();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

