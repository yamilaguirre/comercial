// services/voicemail_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/voicemail_model.dart';

class VoicemailService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Obtener buzón de voz del usuario
  Stream<List<Voicemail>> getUserVoicemails(String userId) {
    return _firestore
        .collection('voicemails')
        .where('user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Voicemail.fromFirestore(doc)).toList());
  }

  // Obtener mensajes no leídos
  Stream<List<Voicemail>> getUnreadVoicemails(String userId) {
    return _firestore
        .collection('voicemails')
        .where('user_id', isEqualTo: userId)
        .where('is_read', isEqualTo: false)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Voicemail.fromFirestore(doc)).toList());
  }

  // Marcar mensaje como leído
  Future<bool> markAsRead(String voicemailId) async {
    try {
      await _firestore.collection('voicemails').doc(voicemailId).update({
        'is_read': true,
      });
      return true;
    } catch (e) {
      print('Error marking voicemail as read: $e');
      return false;
    }
  }

  // Obtener contador de mensajes no leídos
  Stream<int> getUnreadCount(String userId) {
    return _firestore
        .collection('voicemails')
        .where('user_id', isEqualTo: userId)
        .where('is_read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Crear nuevo mensaje de voz
  Future<bool> createVoicemail({
    required String userId,
    required String fromUserId,
    required String fromName,
    String? propertyId,
    required String audioUrl,
    required int durationSeconds,
    required String transcript,
  }) async {
    try {
      await _firestore.collection('voicemails').add({
        'user_id': userId,
        'from_user_id': fromUserId,
        'from_name': fromName,
        'property_id': propertyId,
        'audio_url': audioUrl,
        'duration_seconds': durationSeconds,
        'transcript': transcript,
        'is_read': false,
        'created_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error creating voicemail: $e');
      return false;
    }
  }
}
