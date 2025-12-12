import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';
import '../models/notification_model.dart';

/// Servicio para manejar notificaciones relacionadas con premium
/// Este servicio SOLO envía notificaciones, NO modifica el estado premium en Firebase
/// El admin cambia el estado manualmente en Firebase Console
class PremiumNotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

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
      final hasWorkerProfile = _hasWorkerProfile(userData);

      if (hasWorkerProfile) {
        // 2a. Ya tiene perfil de trabajador -> Notificar a TODOS los usuarios
        await _notifyAllUsersAboutPremiumWorker(userId, userName, userData);
      } else {
        // 2b. No tiene perfil de trabajador -> Notificar solo al usuario
        await _notifyUserAboutPremiumBenefits(userId, userRole);
      }
    } catch (e) {
      print('Error en handleNewPremiumUser: $e');
      // No lanzar error para no interrumpir el flujo
    }
  }

  /// Verifica si el usuario tiene un perfil de trabajador completo
  bool _hasWorkerProfile(Map<String, dynamic> userData) {
    final profile = userData['profile'] as Map<String, dynamic>?;
    if (profile == null) return false;

    final hasProfessions =
        (userData['professions'] as List<dynamic>?)?.isNotEmpty ?? false;
    final hasPortfolio =
        (profile['portfolioImages'] as List<dynamic>?)?.isNotEmpty ?? false;
    final hasDescription =
        (profile['description'] as String?)?.isNotEmpty ?? false;

    return hasProfessions && hasPortfolio && hasDescription;
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
