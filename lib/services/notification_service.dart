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

    // 2. Stream de todas las notificaciones (UNIFICADO: lee de 'notifications')
    await for (final snapshot
        in _firestore
            .collection('notifications')
            .orderBy('created_at', descending: true)
            .limit(100) // Limitar para rendimiento
            .snapshots()) {
      final allNotifications = snapshot.docs
          .map((doc) => AppNotification.fromFirestore(doc))
          .toList();

      // 3. Filtrar notificaciones relevantes para el usuario
      final userNotifications = allNotifications.where((notification) {
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
      }).toList();

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

  // Obtener contador de notificaciones no leídas
  Stream<int> getUnreadCount(String userId) async* {
    await for (final notifications in getNotificationsForUser(userId)) {
      yield notifications.where((n) => !n.isRead).length;
    }
  }

  // Marcar notificación como leída (Actualiza el documento directamente)
  Future<bool> markAsRead(String userId, String notificationId) async {
    try {
      // Solo podemos marcar como leídas las notificaciones que existen como documento
      // y que son "personales" o que queremos marcar en el documento global (cuidado con esto)
      // El usuario pidió "manejarlo dentro del id", asumimos update directo.
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
  Future<bool> markAllAsRead(
    String userId,
    List<String> notificationIds,
  ) async {
    try {
      final batch = _firestore.batch();

      for (final notificationId in notificationIds) {
        final docRef = _firestore
            .collection('notifications')
            .doc(notificationId);
        batch.update(docRef, {'is_read': true});
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
        'created_at':
            FieldValue.serverTimestamp(), // Usar created_at (snake_case)
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
      final docRef = await _firestore.collection('notifications').add({
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
      final docRef = await _firestore.collection('notifications').add({
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

  // Obtener notificaciones para el módulo de propiedades (UNIFICADO: lee de 'notifications')
  Stream<List<AppNotification>> getNotificationsForPropertyModule(
    String userId,
  ) async* {
    await for (final _ in Stream.periodic(const Duration(seconds: 2))) {
      try {
        // Consultar colección unificada 'notifications'
        final notificationsSnapshot = await _firestore
            .collection('notifications')
            .orderBy('created_at', descending: true)
            .limit(50)
            .get();

        final allNotifications = notificationsSnapshot.docs
            .map((doc) => AppNotification.fromFirestore(doc))
            .toList();

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
            .take(100)
            .toList();

        yield userNotifications;
      } catch (e) {
        print('Error fetching property notifications: $e');
      }
    }
  }

  // Obtener notificaciones para el módulo de inmobiliaria (UNIFICADO: lee de 'notifications')
  Stream<List<AppNotification>> getNotificationsForInmobiliariaModule(
    String userId,
  ) async* {
    await for (final _ in Stream.periodic(const Duration(seconds: 2))) {
      try {
        // Consultar colección unificada 'notifications'
        final notificationsSnapshot = await _firestore
            .collection('notifications')
            .orderBy('created_at', descending: true)
            .limit(50)
            .get();

        final allNotifications = notificationsSnapshot.docs
            .map((doc) => AppNotification.fromFirestore(doc))
            .toList();

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
    // Usamos un loop infinito con delay para simular un stream que se actualiza
    while (true) {
      try {
        // Consultar colección unificada 'notifications'
        final notificationsSnapshot = await _firestore
            .collection('notifications')
            .orderBy('created_at', descending: true)
            .limit(50)
            .get();

        final allNotifications = notificationsSnapshot.docs
            .map((doc) => AppNotification.fromFirestore(doc))
            .toList();

        final userNotifications = allNotifications.where((notification) {
          // 1. Mensajes globales (type == 'message') -> Mostrar a todos
          // PERO FILTRAR: Evitar que notificaciones de verificación (que a veces llegan como globales por error)
          // se muestren a todos. Solo permitir anuncios reales.
          if (notification.type == NotificationType.message) {
            // Si el título contiene "Verificación", asume que es privada y NO la muestres como global
            if (notification.title.contains('Verificación') ||
                notification.title.contains('Verification')) {
              return false;
            }
            return true;
          }

          // 2. Notificaciones personales -> Solo si user_id coincide
          if (notification.userId != null && notification.userId!.isNotEmpty) {
            return notification.userId == userId;
          }

          return false;
        }).toList();

        yield userNotifications;
      } catch (e) {
        print('Error fetching worker notifications: $e');
        yield [];
      }

      await Future.delayed(const Duration(seconds: 3));
    }
  }

  // Obtener contador de notificaciones no leídas para trabajador
  Stream<int> getWorkerUnreadCount(String userId) async* {
    await for (final notifications in getWorkerNotifications(userId)) {
      yield notifications.where((n) => !n.isRead).length;
    }
  }
}
