import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String text;
  final Timestamp? timestamp;
  final bool read;
  final List<String> readBy;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.text,
    required this.timestamp,
    required this.read,
    this.readBy = const [],
  });

  factory ChatMessage.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'User',
      senderAvatar: data['senderAvatar'],
      text: data['text'] ?? '',
      timestamp: data['timestamp'],
      read: data['read'] ?? false,
      readBy: List<String>.from(data['readBy'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'text': text,
      'timestamp': timestamp ?? FieldValue.serverTimestamp(),
      'read': read,
      'readBy': readBy,
    };
  }
}

class TypingIndicator {
  final String userId;
  final String userName;
  final Timestamp timestamp;

  TypingIndicator({
    required this.userId,
    required this.userName,
    required this.timestamp,
  });

  factory TypingIndicator.fromMap(Map<String, dynamic> data) {
    return TypingIndicator(
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'User',
      timestamp: data['timestamp'] ?? Timestamp.now(),
    );
  }
}

