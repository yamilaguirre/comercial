import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

class WorkerRepublishService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  // Verificar si el trabajador puede re-publicarse (han pasado 4 horas)
  Future<bool> canRepublish(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;

      final data = userDoc.data();
      final lastRepublish = data?['lastRepublish'] as Timestamp?;

      if (lastRepublish == null) {
        // Si nunca se ha republicado, puede hacerlo
        return true;
      }

      // Verificar si han pasado 7 días
      final now = DateTime.now();
      final lastRepublishDate = lastRepublish.toDate();
      final difference = now.difference(lastRepublishDate);

      return difference.inDays >= 7;
    } catch (e) {
      print('Error checking republish eligibility: $e');
      return false;
    }
  }

  // Obtener tiempo restante para poder re-publicarse
  Future<Duration?> getTimeUntilNextRepublish(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return null;

      final data = userDoc.data();
      final lastRepublish = data?['lastRepublish'] as Timestamp?;

      if (lastRepublish == null) {
        return Duration.zero; // Puede republicarse inmediatamente
      }

      final now = DateTime.now();
      final lastRepublishDate = lastRepublish.toDate();
      final nextRepublishDate = lastRepublishDate.add(const Duration(days: 7));

      if (now.isAfter(nextRepublishDate)) {
        return Duration.zero; // Puede republicarse ya
      }

      return nextRepublishDate.difference(now);
    } catch (e) {
      print('Error getting time until next republish: $e');
      return null;
    }
  }

  // Re-publicar trabajador (actualizar timestamp y programar notificación)
  Future<bool> republishWorker(String userId) async {
    try {
      // Verificar si puede republicarse
      final canPublish = await canRepublish(userId);
      if (!canPublish) {
        return false;
      }

      // Actualizar timestamp de última re-publicación
      await _firestore.collection('users').doc(userId).update({
        'lastRepublish': FieldValue.serverTimestamp(),
      });

      // Programar notificación para dentro de 7 días
      Future.delayed(const Duration(days: 7), () async {
        await _notificationService.createRepublishNotification(userId: userId);
      });

      return true;
    } catch (e) {
      print('Error republishing worker: $e');
      return false;
    }
  }

  // Enviar notificación de re-publicación después de 4 horas
  Future<void> scheduleRepublishNotification(String userId) async {
    try {
      // Verificar si el usuario es trabajador
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final data = userDoc.data();
      final role = data?['role'] as String?;
      final status = data?['status'] as String?;

      // Solo para usuarios en modo trabajo
      if (role != 'trabajo' && status != 'trabajo') return;

      // Verificar si ya pasaron 4 horas desde la última re-publicación
      final timeUntil = await getTimeUntilNextRepublish(userId);
      if (timeUntil == null || timeUntil.inSeconds > 0) return;

      // Enviar notificación
      await _notificationService.createRepublishNotification(userId: userId);
    } catch (e) {
      print('Error scheduling republish notification: $e');
    }
  }

  // Stream para monitorear trabajadores que necesitan notificación
  Stream<List<String>> getWorkersNeedingNotification() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'trabajo')
        .snapshots()
        .asyncMap((snapshot) async {
      final workersNeedingNotification = <String>[];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final lastRepublish = data['lastRepublish'] as Timestamp?;

        if (lastRepublish != null) {
          final now = DateTime.now();
          final lastRepublishDate = lastRepublish.toDate();
          final difference = now.difference(lastRepublishDate);

          // Si han pasado exactamente 4 horas (con margen de 5 minutos)
          if (difference.inMinutes >= 240 && difference.inMinutes <= 245) {
            workersNeedingNotification.add(doc.id);
          }
        }
      }

      return workersNeedingNotification;
    });
  }
}
