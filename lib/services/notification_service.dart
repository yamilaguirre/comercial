// services/notification_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<AppNotification>> getNotificationsForUser(String userId) {
    // Combine real-time snapshots from personal notifications and global notifications
    final personalQuery = _firestore
        .collection('notifications')
        .where('user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .limit(50);

    final globalQuery = _firestore
        .collection('notifications')
        .where('is_global', isEqualTo: true)
        .orderBy('created_at', descending: true)
        .limit(50);

    final controller = StreamController<List<AppNotification>>();
    QuerySnapshot? lastPersonalSnapshot;
    QuerySnapshot? lastGlobalSnapshot;

    late final StreamSubscription personalSub;
    late final StreamSubscription globalSub;

    void emitMerged() {
      try {
        final personalDocs = lastPersonalSnapshot?.docs ?? [];
        final globalDocs = lastGlobalSnapshot?.docs ?? [];
        final allDocs = [...personalDocs, ...globalDocs];

        final notifications = allDocs
            .map((doc) => AppNotification.fromFirestore(doc))
            .toList();

        notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        final limited = notifications.take(100).map((n) {
          return n.copyWith(isRead: n.readUsers.contains(userId));
        }).toList();

        controller.add(limited);
      } catch (e, st) {
        print('Error merging notifications: $e');
        print(st);
        controller.addError(e);
      }
    }

    // Fallback to run queries without ordering when Firestore index is missing
    Future<void> fetchFallbackAndEmit() async {
      try {
        final personalDocs = await _firestore
            .collection('notifications')
            .where('user_id', isEqualTo: userId)
            .limit(100)
            .get();

        final globalDocs = await _firestore
            .collection('notifications')
            .where('is_global', isEqualTo: true)
            .limit(100)
            .get();

        final allDocs = [...personalDocs.docs, ...globalDocs.docs];
        final notifications = allDocs
            .map((doc) => AppNotification.fromFirestore(doc))
            .toList();

        notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        final limited = notifications.take(100).map((n) {
          return n.copyWith(isRead: n.readUsers.contains(userId));
        }).toList();

        controller.add(limited);
      } catch (e, st) {
        print('Fallback fetch error: $e');
        print(st);
        controller.addError(e);
      }
    }

    personalSub = personalQuery.snapshots().listen((snap) {
      lastPersonalSnapshot = snap;
      emitMerged();
    }, onError: (e, st) {
      print('Error personal notifications stream: $e');
      // If index missing, do fallback one-time fetch without orderBy
      final errStr = e?.toString() ?? '';
      if (errStr.contains('requires an index') || errStr.contains('failed-precondition')) {
        fetchFallbackAndEmit();
      } else {
        controller.addError(e);
      }
    });

    globalSub = globalQuery.snapshots().listen((snap) {
      lastGlobalSnapshot = snap;
      emitMerged();
    }, onError: (e, st) {
      print('Error global notifications stream: $e');
      final errStr = e?.toString() ?? '';
      if (errStr.contains('requires an index') || errStr.contains('failed-precondition')) {
        fetchFallbackAndEmit();
      } else {
        controller.addError(e);
      }
    });

    controller.onCancel = () async {
      await personalSub.cancel();
      await globalSub.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  // Obtener contador de notificaciones no leídas
  Stream<int> getUnreadCount(String userId) async* {
    await for (final notifications in getNotificationsForUser(userId)) {
      yield notifications.where((n) => !n.isRead).length;
    }
  }

  // Marcar notificación como leída (Actualiza el array read_users en el documento)
  Future<bool> markAsRead(String userId, String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'read_users': FieldValue.arrayUnion([userId]),
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
        batch.update(docRef, {
          'read_users': FieldValue.arrayUnion([userId]),
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
        'is_global': true, // Flag para mensajes que todos deben ver
        'metadata': metadata,
      });
      print('✅ Notificación global creada: $title');
      return docRef.id;
    } catch (e) {
      print('Error creating system message: $e');
      return null;
    }
  }

  // Crear notificación de re-publicación para trabajador
  Future<String?> createRepublishNotification({required String userId}) async {
    try {
      final docRef = await _firestore.collection('notifications').add({
        'type': NotificationType.message.toFirestore(),
        'title': '📢 ¡Destaca tu perfil!',
        'message':
            'Han pasado 7 días. Re-publica tu perfil para aparecer al inicio de la lista y conseguir más clientes.',
        'user_id': userId,
        'created_at': FieldValue.serverTimestamp(),
        'metadata': {'action': 'republish_worker'},
      });
      return docRef.id;
    } catch (e) {
      print('Error creating republish notification: $e');
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
        final userPropertyIds = await _getUserPropertyIds(userId);

        // Consultar colección unificada 'notifications'
        final notificationsSnapshot = await _firestore
            .collection('notifications')
            .orderBy('created_at', descending: true)
            .limit(50)
            .get();

        final validNotifications = <AppNotification>[];

        for (final doc in notificationsSnapshot.docs) {
          final notification = AppNotification.fromFirestore(doc);

          // --- LÓGICA DE AUTO-LIMPIEZA DE SPAM ---
          if (notification.title.contains('¡Bienvenido a Premium!')) {
            doc.reference.delete();
            continue;
          }
          // ---------------------------------------

          validNotifications.add(notification);
        }

        final userNotifications = validNotifications
            .where((notification) {
              // 1. Si tiene un usuario específico, solo mostrar a ese usuario
              if (notification.userId != null &&
                  notification.userId!.isNotEmpty) {
                return notification.userId == userId;
              }

              // 2. Si tiene property_id, solo mostrar si es del usuario
              if (notification.propertyId != null &&
                  notification.propertyId!.isNotEmpty) {
                return userPropertyIds.contains(notification.propertyId);
              }

              // 3. Si NO tiene usuario ni property_id (es global), mostrar a todos
              return true;
            })
            .map(
              (notification) => notification.copyWith(
                isRead: notification.readUsers.contains(userId),
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

  // Obtener notificaciones para el módulo de inmobiliaria (UNIFICADO: lee de 'notifications')
  Stream<List<AppNotification>> getNotificationsForInmobiliariaModule(
    String userId,
  ) async* {
    await for (final _ in Stream.periodic(const Duration(seconds: 2))) {
      try {
        final userPropertyIds = await _getUserPropertyIds(userId);

        // Consultar colección unificada 'notifications'
        final notificationsSnapshot = await _firestore
            .collection('notifications')
            .orderBy('created_at', descending: true)
            .limit(50)
            .get();

        final validNotifications = <AppNotification>[];

        for (final doc in notificationsSnapshot.docs) {
          final notification = AppNotification.fromFirestore(doc);

          // --- LÓGICA DE AUTO-LIMPIEZA DE SPAM ---
          if (notification.title.contains('¡Bienvenido a Premium!')) {
            doc.reference.delete();
            continue;
          }
          // ---------------------------------------

          validNotifications.add(notification);
        }

        final userNotifications = validNotifications
            .where((notification) {
              // 1. Si tiene un usuario específico, solo mostrar a ese usuario
              if (notification.userId != null &&
                  notification.userId!.isNotEmpty) {
                return notification.userId == userId;
              }

              // 2. Si tiene property_id, solo mostrar si es del usuario
              if (notification.propertyId != null &&
                  notification.propertyId!.isNotEmpty) {
                return userPropertyIds.contains(notification.propertyId);
              }

              // 3. Si NO tiene usuario ni property_id (es global), mostrar a todos
              return true;
            })
            .map(
              (notification) => notification.copyWith(
                isRead: notification.readUsers.contains(userId),
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

  // Obtener IDs de propiedades del usuario
  Future<Set<String>> _getUserPropertyIds(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('properties')
          .where('owner_id', isEqualTo: userId)
          .get();
      return snapshot.docs.map((doc) => doc.id).toSet();
    } catch (e) {
      print('Error getting user property IDs: $e');
      return {};
    }
  }
}
