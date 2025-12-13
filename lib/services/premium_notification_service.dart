import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';
import '../models/notification_model.dart';

/// Servicio para manejar notificaciones relacionadas con premium
/// Este servicio SOLO envía notificaciones, NO modifica el estado premium en Firebase
/// El admin cambia el estado manualmente en Firebase Console
class PremiumNotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  /// Notifica a todos los usuarios cuando un trabajador premium crea su perfil
  /// Se llama desde freelance_work.dart cuando un usuario premium guarda su perfil por primera vez
  Future<void> handleNewWorkerProfile(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        print('Usuario no encontrado: $userId');
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final userName = userData['displayName'] ?? 'Usuario';

      // Verificar si tiene perfil de trabajador completo (incluye fallback a freelance_work)
      final hasWorkerProfile = await _hasWorkerProfileAsync(userId, userData);

      if (!hasWorkerProfile) {
        print('ℹ️ Usuario premium sin perfil trabajador completo: $userName');
        return;
      }

      // Usar transacción para asegurar que la notificación global se envía solo una vez
      final premiumRef = _firestore.collection('premium_users').doc(userId);
      bool shouldNotify = false;

      try {
        await _firestore.runTransaction((tx) async {
          final snap = await tx.get(premiumRef);
          if (!snap.exists) {
            // Si no existe registro en premium_users, no asumimos premium y no notificamos
            return;
          }

          final data = snap.data() as Map<String, dynamic>;
          final status = data['status'] as String?;
          final alreadyGlobal = data['global_worker_notified'] == true;

          if (status == 'active' && !alreadyGlobal) {
            tx.update(premiumRef, {'global_worker_notified': true});
            shouldNotify = true;
          }
        });
      } catch (e) {
        print('Error en transacción global notify check: $e');
      }

      if (shouldNotify) {
        // Enviar notificación global fuera de la transacción
        await _notifyAllUsersAboutPremiumWorker(userId, userName, userData);
        print('✅ Notificación global enviada para nuevo trabajador premium: $userName');
      } else {
        print('ℹ️ Notificación global ya enviada previamente o usuario no es premium: $userName');
      }
    } catch (e) {
      print('Error en handleNewWorkerProfile: $e');
    }
  }

  /// Maneja las notificaciones cuando detecta que un usuario se volvió premium
  /// Este método debe ser llamado cuando la app detecte que premium_users/{userId}.status cambió a "active"
  Future<void> handleNewPremiumUser(String userId) async {
    try {
      // 1. Obtener datos del usuario
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        print('Usuario no encontrado: $userId');
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final userName = userData['displayName'] ?? 'Usuario';
      final userRole = userData['role'] ?? '';

      // 2. Verificar si tiene perfil de trabajador
      final hasWorkerProfile = await _hasWorkerProfileAsync(userId, userData);

      if (hasWorkerProfile) {
        // 2a. Ya tiene perfil de trabajador -> Notificar a TODOS los usuarios
        // Usar transacción para evitar duplicados (marca global_worker_notified)
        final premiumRef = _firestore.collection('premium_users').doc(userId);
        bool shouldNotifyGlobal = false;

        try {
          await _firestore.runTransaction((tx) async {
            final snap = await tx.get(premiumRef);
            if (!snap.exists) {
              // No existe registro en premium_users -> no asumimos premium
              return;
            }

            final data = snap.data() as Map<String, dynamic>;
            final status = data['status'] as String?;
            final alreadyGlobal = data['global_worker_notified'] == true;

            if (status == 'active' && !alreadyGlobal) {
              tx.update(premiumRef, {'global_worker_notified': true});
              shouldNotifyGlobal = true;
            }
          });
        } catch (e) {
          print('Error en transacción para notificación global (premium user): $e');
        }

        if (shouldNotifyGlobal) {
          await _notifyAllUsersAboutPremiumWorker(userId, userName, userData);
        } else {
          print('ℹ️ Notificación global ya enviada previamente o usuario no es premium: $userName');
        }

        return;
      }

      // 2b. No tiene perfil de trabajador -> Notificar solo al usuario
      // Usar transacción para marcar en premium_users que ya se envió welcome
      final premiumRef = _firestore.collection('premium_users').doc(userId);
      bool shouldNotifyUser = false;
      try {
        await _firestore.runTransaction((tx) async {
          final premiumSnap = await tx.get(premiumRef);
          if (!premiumSnap.exists) {
            // Si no existe registro en premium_users, crear uno con welcome_sent=true
            tx.set(premiumRef, {'status': 'active', 'welcome_sent': true}, SetOptions(merge: true));
            shouldNotifyUser = true;
            return;
          }

          final premiumData = premiumSnap.data() as Map<String, dynamic>;
          final status = premiumData['status'] as String?;
          final alreadySent = premiumData['welcome_sent'] == true;

          if (status == 'active' && !alreadySent) {
            // Marcar welcome_sent dentro de la transacción y notificar después
            tx.update(premiumRef, {'welcome_sent': true});
            shouldNotifyUser = true;
          } else {
            print('✅ Welcome already sent or premium not active for $userId');
          }
        });
      } catch (e) {
        print('Error en transacción welcome check: $e');
      }

      if (shouldNotifyUser) {
        await _notifyUserAboutPremiumBenefits(userId, userRole);
      }
    } catch (e) {
      print('Error en handleNewPremiumUser: $e');
      // No lanzar error para no interrumpir el flujo
    }
  }

  /// Verifica si el usuario tiene un perfil de trabajador completo
  /// Comprueba si el usuario tiene un perfil de trabajador.
  ///
  /// Se considera válido cuando tiene al menos profesiones y descripción.
  /// Además, como fallback, comprueba la colección `freelance_work` por si
  /// el perfil fue guardado ahí en lugar de en `users/{uid}/profile`.
  Future<bool> _hasWorkerProfileAsync(
      String userId, Map<String, dynamic> userData) async {
    final profile = userData['profile'] as Map<String, dynamic>?;

    final hasProfessions =
        (userData['professions'] as List<dynamic>?)?.isNotEmpty ?? false;

    final hasProfessionsInProfile =
        (profile?['professions'] as List<dynamic>?)?.isNotEmpty ?? false;

    final hasDescriptionInProfile =
        (profile?['description'] as String?)?.trim().isNotEmpty ?? false;

    final hasDescriptionRoot =
        (userData['description'] as String?)?.trim().isNotEmpty ?? false;

    final hasProfessionsFinal = hasProfessions || hasProfessionsInProfile;
    final hasDescriptionFinal = hasDescriptionInProfile || hasDescriptionRoot;

    if (hasProfessionsFinal && hasDescriptionFinal) {
      return true;
    }

    // Fallback: comprobar colección `freelance_work` por si el perfil se guardó allí
    try {
      final docRef = _firestore.collection('freelance_work').doc(userId);
      final doc = await docRef.get();
      if (doc.exists) {
        final fw = doc.data() as Map<String, dynamic>?;
        if (fw != null) {
          final fwProfessions = (fw['professions'] as List<dynamic>?)?.isNotEmpty ?? false;
          final fwDescription = (fw['description'] as String?)?.trim().isNotEmpty ?? false;
          if (fwProfessions && fwDescription) return true;
          // Also accept if there is at least professions + photo/other fields
          final fwPortfolio = (fw['portfolioImages'] as List<dynamic>?)?.isNotEmpty ?? false;
          final fwPhoto = (fw['photoUrl'] as String?)?.trim().isNotEmpty ?? false;
          if (fwProfessions && (fwPortfolio || fwPhoto || fwDescription)) return true;
        }
      } else {
        // Intentar buscar por campo userId/uid en caso de que el doc id no sea uid
        final query = await _firestore
            .collection('freelance_work')
            .where('uid', isEqualTo: userId)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          final fw = query.docs.first.data();
          final fwProfessions = (fw['professions'] as List<dynamic>?)?.isNotEmpty ?? false;
          final fwDescription = (fw['description'] as String?)?.trim().isNotEmpty ?? false;
          if (fwProfessions && fwDescription) return true;
        }
      }
    } catch (e) {
      print('Error comprobando freelance_work para $userId: $e');
    }

    return false;
  }

  /// Notifica a TODOS los usuarios sobre un nuevo trabajador premium
  Future<void> _notifyAllUsersAboutPremiumWorker(
    String userId,
    String userName,
    Map<String, dynamic> userData,
  ) async {
    try {
      // Obtener las profesiones del trabajador
      final professions = userData['professions'] as List<dynamic>?;
      String professionText = 'servicios profesionales';

      if (professions != null && professions.isNotEmpty) {
        final List<String> allSubcategories = [];
        for (var prof in professions) {
          if (prof is Map<String, dynamic>) {
            final subs = prof['subcategories'] as List<dynamic>?;
            if (subs != null && subs.isNotEmpty) {
              allSubcategories.addAll(subs.map((e) => e.toString()));
            }
          }
        }
        if (allSubcategories.isNotEmpty) {
          professionText = allSubcategories.take(2).join(' y ');
        }
      }

      // Crear notificación del sistema para TODOS
      await _notificationService.createSystemMessage(
        title: '⭐ ¡Nuevo Profesional Premium!',
        message:
            '$userName ahora ofrece sus servicios de $professionText con garantía Premium',
        metadata: {
          'userId': userId,
          'profession': professionText,
          'type': 'premium_worker',
        },
      );

      print(
        '✅ Notificación global enviada sobre trabajador premium: $userName',
      );
    } catch (e) {
      print('Error notificando sobre trabajador premium: $e');
    }
  }

  /// Notifica al usuario sobre los beneficios premium disponibles
  Future<void> _notifyUserAboutPremiumBenefits(
    String userId,
    String userRole,
  ) async {
    try {
      String title = '';
      String message = '';

      if (userRole == 'inmobiliaria' || userRole == 'inmobiliaria_empresa') {
        // Usuario de inmobiliaria
        title = '🏠 ¡Premium Inmobiliaria Activado!';
        message =
            'Ahora tienes acceso a:\n'
            '• Publicaciones ilimitadas\n'
            '• Análisis avanzado de propiedades\n'
            '• Soporte prioritario\n'
            '• Y mucho más...';
      } else {
        // Usuario trabajador o cliente
        title = '🚀 ¡Activa tu Perfil Profesional!';
        message =
            '¡Felicidades! Ahora eres Premium.\n\n'
            '💼 ¿Sabías que puedes crear un perfil de trabajador?\n'
            'Ofrece tus servicios y accede a videos en tu portafolio.\n\n'
            'Crea tu perfil desde la sección de Trabajador.';
      }

      // 0. VERIFICACIÓN DE SEGURIDAD (IDEMPOTENCIA)
      // Comprobar si ya existe una notificación con este título para evitar bucles
      final existingNotifications = await _firestore
          .collection('notifications')
          .where('user_id', isEqualTo: userId)
          .where('title', isEqualTo: title)
          .limit(1)
          .get();

      if (existingNotifications.docs.isNotEmpty) {
        print('⚠️ Notificación premium ya enviada previamente. Omitiendo.');
        return;
      }

      // Usar tipo 'message' para notificaciones premium personales
      await _notificationService.createProfileChangeNotification(
        userId: userId,
        type: NotificationType.message,
        title: title,
        message: message,
        metadata: {'premium_welcome': true, 'role': userRole},
      );

      print('✅ Notificación enviada al usuario premium: $userId');
    } catch (e) {
      print('Error notificando al usuario sobre premium: $e');
    }
  }
}
