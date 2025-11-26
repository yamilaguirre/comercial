// services/chat_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Obtener chats del usuario
  Stream<List<Chat>> getUserChats(String userId) {
    return _firestore
        .collection('chats')
        .where('user_ids', arrayContains: userId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Chat.fromFirestore(doc)).toList(),
        );
  }

  // Obtener chat específico
  Stream<Chat?> getChatById(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .snapshots()
        .map((doc) => doc.exists ? Chat.fromFirestore(doc) : null);
  }

  // Enviar mensaje
  Future<bool> sendMessage(
    String chatId,
    String senderId,
    String text, {
    String? messageType,
    String? attachmentUrl,
    String? fileName,
  }) async {
    try {
      final chatRef = _firestore.collection('chats').doc(chatId);
      final now = Timestamp.now();

      final messageData = {
        'sender_id': senderId,
        'text': text,
        'timestamp': now, // Usar Timestamp.now() NO serverTimestamp en arrays
      };

      // Agregar datos de archivo si existen
      if (messageType != null) {
        messageData['type'] = messageType;
      }
      if (attachmentUrl != null) {
        messageData['attachment_url'] = attachmentUrl;
      }
      if (fileName != null) {
        messageData['file_name'] = fileName;
      }

      await chatRef.update({
        'messages': FieldValue.arrayUnion([messageData]),
        'last_message': text,
        'last_updated': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  // Crear nuevo chat
  Future<String?> createChat({
    required String propertyId,
    required List<String> userIds,
    required String initialMessage,
    required String senderId,
  }) async {
    try {
      final now = Timestamp.now();

      final docRef = await _firestore.collection('chats').add({
        'property_id': propertyId,
        'user_ids': userIds,
        'last_message': initialMessage,
        'last_updated': FieldValue.serverTimestamp(),
        'messages': [
          {
            'sender_id': senderId,
            'text': initialMessage,
            'timestamp':
                now, // Usar Timestamp.now() NO serverTimestamp en arrays
          },
        ],
      });

      return docRef.id;
    } catch (e) {
      print('Error creating chat: $e');
      return null;
    }
  }

  // Buscar chat existente entre usuarios para una propiedad
  Future<String?> findExistingChat(
    String propertyId,
    List<String> userIds,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('chats')
          .where('property_id', isEqualTo: propertyId)
          .where('user_ids', arrayContainsAny: userIds)
          .get();

      for (var doc in snapshot.docs) {
        final chatUserIds = List<String>.from(doc.data()['user_ids']);
        if (chatUserIds.toSet().containsAll(userIds.toSet())) {
          return doc.id;
        }
      }

      return null;
    } catch (e) {
      print('Error finding existing chat: $e');
      return null;
    }
  }
}
