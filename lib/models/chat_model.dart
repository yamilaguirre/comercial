// models/chat_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, file, video }

class ChatMessage {
  final String senderId;
  final String text;
  final DateTime timestamp;
  final MessageType type;
  final String? attachmentUrl;
  final String? fileName;

  ChatMessage({
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.type = MessageType.text,
    this.attachmentUrl,
    this.fileName,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> data) {
    // Determinar el tipo de mensaje
    MessageType messageType = MessageType.text;
    if (data['type'] != null) {
      switch (data['type']) {
        case 'image':
          messageType = MessageType.image;
          break;
        case 'file':
          messageType = MessageType.file;
          break;
        case 'video':
          messageType = MessageType.video;
          break;
        default:
          messageType = MessageType.text;
      }
    }

    return ChatMessage(
      senderId: data['sender_id'] ?? '',
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      type: messageType,
      attachmentUrl: data['attachment_url'],
      fileName: data['file_name'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sender_id': senderId,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type.name,
      'attachment_url': attachmentUrl,
      'file_name': fileName,
    };
  }
}

class Chat {
  final String id;
  final String propertyId;
  final List<String> userIds;
  final String lastMessage;
  final DateTime lastUpdated;
  final List<ChatMessage> messages;
  final Map<String, DateTime>
  lastRead; // Cuándo cada usuario leyó por última vez

  Chat({
    required this.id,
    required this.propertyId,
    required this.userIds,
    required this.lastMessage,
    required this.lastUpdated,
    required this.messages,
    Map<String, DateTime>? lastRead,
  }) : lastRead = lastRead ?? {};

  factory Chat.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final messagesData = data['messages'] as List<dynamic>? ?? [];

    // Parsear lastRead del documento
    final lastReadData = data['last_read'] as Map<String, dynamic>?;
    final Map<String, DateTime> lastReadMap = {};

    if (lastReadData != null) {
      lastReadData.forEach((userId, timestamp) {
        if (timestamp is Timestamp) {
          lastReadMap[userId] = timestamp.toDate();
        }
      });
    }

    return Chat(
      id: doc.id,
      propertyId: data['property_id'] ?? '',
      userIds: List<String>.from(data['user_ids'] ?? []),
      lastMessage: data['last_message'] ?? '',
      lastUpdated: (data['last_updated'] as Timestamp).toDate(),
      messages: messagesData.map((msg) => ChatMessage.fromMap(msg)).toList(),
      lastRead: lastReadMap,
    );
  }

  // Calcular mensajes no leídos para un usuario específico
  int getUnreadCount(String userId) {
    final userLastRead = lastRead[userId];

    // Si nunca ha leído, todos los mensajes del otro usuario son no leídos
    if (userLastRead == null) {
      return messages.where((msg) => msg.senderId != userId).length;
    }

    // Contar mensajes después del último leído que no son del usuario actual
    return messages.where((msg) {
      return msg.senderId != userId && msg.timestamp.isAfter(userLastRead);
    }).length;
  }
}
