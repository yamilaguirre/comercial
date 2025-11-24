// models/chat_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String senderId;
  final String text;
  final DateTime timestamp;

  ChatMessage({
    required this.senderId,
    required this.text,
    required this.timestamp,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> data) {
    return ChatMessage(
      senderId: data['sender_id'] ?? '',
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }
}

class Chat {
  final String id;
  final String propertyId;
  final List<String> userIds;
  final String lastMessage;
  final DateTime lastUpdated;
  final List<ChatMessage> messages;

  Chat({
    required this.id,
    required this.propertyId,
    required this.userIds,
    required this.lastMessage,
    required this.lastUpdated,
    required this.messages,
  });

  factory Chat.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final messagesData = data['messages'] as List<dynamic>? ?? [];
    
    return Chat(
      id: doc.id,
      propertyId: data['property_id'] ?? '',
      userIds: List<String>.from(data['user_ids'] ?? []),
      lastMessage: data['last_message'] ?? '',
      lastUpdated: (data['last_updated'] as Timestamp).toDate(),
      messages: messagesData.map((msg) => ChatMessage.fromMap(msg)).toList(),
    );
  }
}