// services/notification_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import 'saved_list_service.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SavedListService _savedListService = SavedListService();

  // Obtener notificaciones para un usuario (filtrado dinámico)
  Stream<List<AppNotification>> getNotificationsForUser(String userId) async* {
    // 1. Obtener IDs de propiedades guardadas del usuario
    final savedPropertyIds = await _getSavedPropertyIds(userId);

    // 2. Obtener IDs de notificaciones leídas
    final readNotificationIds = await _getReadNotificationIds(userId);

    // 3. Stream de todas las notificaciones
    await for (final snapshot
        in _firestore
            .collection('notifications')
            .orderBy('created_at', descending: true)
            .limit(100) // Limitar para rendimiento
            .snapshots()) {
      final allNotifications = snapshot.docs
          .map((doc) => AppNotification.fromFirestore(doc))
          .toList();

      // 4. Filtrar notificaciones relevantes para el usuario
      final userNotifications = allNotifications
          .where((notification) {
            // Mensajes de sistema: mostrar a todos
            if (notification.type == NotificationType.message) {
              return true;
            }

            // Notificaciones de propiedades: solo si el usuario tiene la propiedad guardada
            if (notification.propertyId != null) {
              return savedPropertyIds.contains(notification.propertyId);
            }

            // Notificaciones de perfil: solo si son para este usuario específico
            if (notification.userId != null) {
              return notification.userId == userId;
            }

            return false;
          })
          .map((notification) {
            // Agregar estado de leído
            return notification.copyWith(
              isRead: readNotificationIds.contains(notification.id),
            );
          })
          .toList();

      yield userNotifications;
    }
  }

  // Obtener IDs de propiedades guardadas del usuario
  Future<Set<String>> _getSavedPropertyIds(String userId) async {
    try {
      final properties = await _savedListService.getAllSavedProperties(userId);
      return properties.map((p) => p.id).toSet();
    } catch (e) {
      print('Error getting saved property IDs: $e');
      return {};
    }
  }

  // Obtener IDs de notificaciones leídas por el usuario
  Future<Set<String>> _getReadNotificationIds(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('notification_reads')
          .where('user_id', isEqualTo: userId)
          .get();

      return snapshot.docs
          .map((doc) => doc.data()['notification_id'] as String)
          .toSet();
    } catch (e) {
      print('Error getting read notification IDs: $e');
      return {};
    }
  }

  // Obtener contador de notificaciones no leídas
  Stream<int> getUnreadCount(String userId) async* {
    await for (final notifications in getNotificationsForUser(userId)) {
      yield notifications.where((n) => !n.isRead).length;
    }
  }

  // Marcar notificación como leída
  Future<bool> markAsRead(String userId, String notificationId) async {
    try {
      final docId = '${userId}_$notificationId';
      await _firestore.collection('notification_reads').doc(docId).set({
        'user_id': userId,
        'notification_id': notificationId,
        'read_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error marking notification as read: $e');
      return false;
    }
  }

  // Marcar todas las notificaciones como leídas
  Future<bool> markAllAsRead(
    String userId,
    List<String> notificationIds,
  ) async {
    try {
      final batch = _firestore.batch();

      for (final notificationId in notificationIds) {
        final docId = '${userId}_$notificationId';
        batch.set(_firestore.collection('notification_reads').doc(docId), {
          'user_id': userId,
          'notification_id': notificationId,
          'read_at': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      return true;
    } catch (e) {
      print('Error marking all notifications as read: $e');
      return false;
    }
  }

  // Crear notificación de propiedad (bajada de precio, etc.)
  Future<String?> createPropertyNotification({
    required NotificationType type,
    required String title,
    required String message,
    required String propertyId,
    double? oldPrice,
    double? newPrice,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final docRef = await _firestore.collection('notifications').add({
        'type': type.toFirestore(),
        'title': title,
        'message': message,
        'property_id': propertyId,
        'old_price': oldPrice,
        'new_price': newPrice,
        'created_at': FieldValue.serverTimestamp(),
        'metadata': metadata,
      });
      return docRef.id;
    } catch (e) {
      print('Error creating property notification: $e');
      return null;
    }
  }

  // Crear mensaje de sistema (visible para todos)
  Future<String?> createSystemMessage({
    required String title,
    required String message,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final docRef = await _firestore.collection('notifications').add({
        'type': NotificationType.message.toFirestore(),
        'title': title,
        'message': message,
        'created_at': FieldValue.serverTimestamp(),
        'metadata': metadata,
      });
      return docRef.id;
    } catch (e) {
      print('Error creating system message: $e');
      return null;
    }
  }

  // Crear notificación de cambio de perfil (solo para el usuario específico)
  Future<String?> createProfileChangeNotification({
    required String userId,
    required NotificationType type,
    required String title,
    required String message,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final docRef = await _firestore.collection('notifications').add({
        'type': type.toFirestore(),
        'title': title,
        'message': message,
        'user_id': userId,
        'created_at': FieldValue.serverTimestamp(),
        'metadata': metadata,
      });
      return docRef.id;
    } catch (e) {
      print('Error creating profile change notification: $e');
      return null;
    }
  }

  // Eliminar notificación
  Future<bool> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
      return true;
    } catch (e) {
      print('Error deleting notification: $e');
      return false;
    }
  }

  // ===== MÉTODOS PARA NOTIFICACIONES DE PROPIEDADES PREMIUM =====

  // Crear notificación de propiedad premium en notification_property
  Future<String?> createPropertyNotificationInPropertyCollection({
    required NotificationType type,
    required String title,
    required String message,
    required String propertyId,
    double? oldPrice,
    double? newPrice,
  }) async {
    try {
      final docRef = await _firestore.collection('notification_property').add({
        'type': type.toFirestore(),
        'title': title,
        'message': message,
        'property_id': propertyId,
        'created_at': FieldValue.serverTimestamp(),
        if (oldPrice != null) 'old_price': oldPrice,
        if (newPrice != null) 'new_price': newPrice,
      });
      return docRef.id;
    } catch (e) {
      print('Error creating property notification: $e');
      return null;
    }
  }

  // Crear notificación de nueva propiedad premium
  Future<String?> createPremiumPropertyNotification({
    required String propertyId,
    required String propertyTitle,
    required String propertyPrice,
    required String propertyType,
    required String location,
  }) async {
    try {
      final docRef = await _firestore.collection('notification_property').add({
        'type': NotificationType.premiumPropertyPublished.toFirestore(),
        'title': '🌟 Nueva Propiedad Premium',
        'message': '$propertyTitle en $location - $propertyPrice',
        'property_id': propertyId,
        'created_at': FieldValue.serverTimestamp(),
        'metadata': {
          'property_title': propertyTitle,
          'property_price': propertyPrice,
          'property_type': propertyType,
          'location': location,
        },
      });
      return docRef.id;
    } catch (e) {
      print('Error creating premium property notification: $e');
      return null;
    }
  }

  // Obtener notificaciones para el módulo de propiedades (notifications + notification_property)
  Stream<List<AppNotification>> getNotificationsForPropertyModule(
    String userId,
  ) async* {
    final readNotificationIds = await _getReadNotificationIds(userId);

    await for (final _ in Stream.periodic(const Duration(seconds: 2))) {
      try {
        final notificationsSnapshot = await _firestore
            .collection('notifications')
            .orderBy('created_at', descending: true)
            .limit(50)
            .get();

        final propertyNotificationsSnapshot = await _firestore
            .collection('notification_property')
            .orderBy('created_at', descending: true)
            .limit(50)
            .get();

        final allNotifications = [
          ...notificationsSnapshot.docs.map(
            (doc) => AppNotification.fromFirestore(doc),
          ),
          ...propertyNotificationsSnapshot.docs.map(
            (doc) => AppNotification.fromFirestore(doc),
          ),
        ];

        allNotifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        final userNotifications = allNotifications
            .where((notification) {
              // 1. Si tiene un usuario específico, solo mostrar a ese usuario
              if (notification.userId != null &&
                  notification.userId!.isNotEmpty) {
                return notification.userId == userId;
              }

              // 2. Si NO tiene usuario específico (es pública/global), mostrar a todos
              return true;
            })
            .map(
              (notification) => notification.copyWith(
                isRead: readNotificationIds.contains(notification.id),
              ),
            )
            .take(100)
            .toList();

        yield userNotifications;
      } catch (e) {
        print('Error fetching property notifications: $e');
      }
    }
  }

  // Obtener notificaciones para el módulo de inmobiliaria (notifications + notification_inmobiliaria)
  Stream<List<AppNotification>> getNotificationsForInmobiliariaModule(
    String userId,
  ) async* {
    final readNotificationIds = await _getReadNotificationIds(userId);

    await for (final _ in Stream.periodic(const Duration(seconds: 2))) {
      try {
        final notificationsSnapshot = await _firestore
            .collection('notifications')
            .orderBy('created_at', descending: true)
            .limit(50)
            .get();

        final inmobiliariaNotificationsSnapshot = await _firestore
            .collection('notification_inmobiliaria')
            .orderBy('created_at', descending: true)
            .limit(50)
            .get();

        final allNotifications = [
          ...notificationsSnapshot.docs.map(
            (doc) => AppNotification.fromFirestore(doc),
          ),
          ...inmobiliariaNotificationsSnapshot.docs.map(
            (doc) => AppNotification.fromFirestore(doc),
          ),
        ];

        allNotifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        final userNotifications = allNotifications
            .where((notification) {
              // 1. Si tiene un usuario específico, solo mostrar a ese usuario
              if (notification.userId != null &&
                  notification.userId!.isNotEmpty) {
                return notification.userId == userId;
              }

              // 2. Si NO tiene usuario específico (es pública/global), mostrar a todos
              return true;
            })
            .map(
              (notification) => notification.copyWith(
                isRead: readNotificationIds.contains(notification.id),
              ),
            )
            .take(100)
            .toList();

        yield userNotifications;
      } catch (e) {
        print('Error fetching inmobiliaria notifications: $e');
      }
    }
  }

  // Obtener notificaciones para el trabajador (notification_worker + notifications filtradas por usuario)
  Stream<List<AppNotification>> getWorkerNotifications(String userId) async* {
    final readNotificationIds = await _getReadNotificationIds(userId);

    // Usamos Stream.periodic para simular un stream combinado que se actualiza
    // Esto es necesario porque estamos combinando dos colecciones diferentes
    await for (final _ in Stream.periodic(const Duration(seconds: 3))) {
      try {
        // 1. Obtener notificaciones de la colección específica de trabajadores
        // Filtramos directamente en la query por user_id para eficiencia y seguridad
        // NOTA: notification_worker usa 'createdAt' (camelCase), no 'created_at'
        final workerNotificationsSnapshot = await _firestore
            .collection('notification_worker')
            .where('user_id', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .limit(50)
            .get();

        // 2. Obtener notificaciones generales que sean PARA ESTE USUARIO
        // NO traemos notificaciones globales aquí, solo las dirigidas al usuario
        final generalNotificationsSnapshot = await _firestore
            .collection('notifications')
            .where('user_id', isEqualTo: userId)
            .orderBy('created_at', descending: true)
            .limit(20)
            .get();

        final allNotifications = [
          ...workerNotificationsSnapshot.docs.map(
            (doc) => AppNotification.fromFirestore(doc),
          ),
          ...generalNotificationsSnapshot.docs.map(
            (doc) => AppNotification.fromFirestore(doc),
          ),
        ];

        // Ordenar por fecha descendente
        allNotifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        // Mapear estado de lectura
        final userNotifications = allNotifications
            .map(
              (notification) => notification.copyWith(
                isRead: readNotificationIds.contains(notification.id),
              ),
            )
            .toList();

        yield userNotifications;
      } catch (e) {
        print('Error fetching worker notifications: $e');
        // En caso de error, intentamos devolver una lista vacía para no romper la UI
        yield [];
      }
    }
  }

  // Obtener contador de notificaciones no leídas para trabajador
  Stream<int> getWorkerUnreadCount(String userId) async* {
    await for (final notifications in getWorkerNotifications(userId)) {
      yield notifications.where((n) => !n.isRead).length;
    }
  }
}
