// services/notification_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Obtener notificaciones del usuario
  Stream<List<AppNotification>> getUserNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => AppNotification.fromFirestore(doc)).toList());
  }

  // Obtener notificaciones no leídas
  Stream<List<AppNotification>> getUnreadNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('user_id', isEqualTo: userId)
        .where('is_read', isEqualTo: false)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => AppNotification.fromFirestore(doc)).toList());
  }

  // Marcar notificación como leída
  Future<bool> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'is_read': true,
      });
      return true;
    } catch (e) {
      print('Error marking notification as read: $e');
      return false;
    }
  }

  // Marcar todas las notificaciones como leídas
  Future<bool> markAllAsRead(String userId) async {
    try {
      final batch = _firestore.batch();
      final snapshot = await _firestore
          .collection('notifications')
          .where('user_id', isEqualTo: userId)
          .where('is_read', isEqualTo: false)
          .get();

      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'is_read': true});
      }

      await batch.commit();
      return true;
    } catch (e) {
      print('Error marking all notifications as read: $e');
      return false;
    }
  }

  // Obtener contador de notificaciones no leídas
  Stream<int> getUnreadCount(String userId) {
    return _firestore
        .collection('notifications')
        .where('user_id', isEqualTo: userId)
        .where('is_read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Crear nueva notificación
  Future<bool> createNotification({
    required String userId,
    required String type,
    required String title,
    required String message,
    String? propertyId,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'user_id': userId,
        'type': type,
        'title': title,
        'message': message,
        'property_id': propertyId,
        'is_read': false,
        'created_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error creating notification: $e');
      return false;
    }
  }
}