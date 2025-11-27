import '../../../services/notification_service.dart';
import '../../../models/notification_model.dart';

/// Script de prueba para crear notificaciones de ejemplo
///
/// USO:
/// 1. Importa este archivo donde lo necesites
/// 2. Llama a createTestNotifications(userId)
/// 3. Verifica en la pantalla de Avisos
class TestNotifications {
  static final NotificationService _notificationService = NotificationService();

  /// Crear todas las notificaciones de prueba
  static Future<void> createAllTestNotifications(String userId) async {
    print('🔔 Creando notificaciones de prueba...');

    await createPriceDropHome(userId);
    await createPriceDropTrend(userId);
    await createPropertyAvailable(userId);
    await createNewProperty(userId);
    await createMessage(userId);

    print('✅ Notificaciones de prueba creadas!');
  }

  /// Notificación 1: Rebaja de precio (Casa Azul 🏠)
  static Future<void> createPriceDropHome(String userId) async {
    await _notificationService.createNotification(
      userId: userId,
      type: NotificationType.priceDropHome,
      title: 'Rebaja de precio',
      message: 'La casa en Calacoto bajó a 1,500,000 Bs',
      propertyId: null, // Puedes poner un ID real si quieres
      metadata: {
        'old_price': 1800000,
        'new_price': 1500000,
        'property_title': 'Casa en Calacoto',
      },
    );
    print('✓ Creada: Rebaja de precio (Casa Azul)');
  }

  /// Notificación 2: Rebaja de precio (Tendencia Verde 📉)
  static Future<void> createPriceDropTrend(String userId) async {
    await _notificationService.createNotification(
      userId: userId,
      type: NotificationType.priceDropTrend,
      title: 'Rebaja de precio',
      message: 'Casa en San Miguel ahora 890,000 Bs',
      propertyId: null,
      metadata: {'old_price': 950000, 'new_price': 890000},
    );
    print('✓ Creada: Rebaja de precio (Tendencia Verde)');
  }

  /// Notificación 3: Propiedad disponible (Campana Morada 🔔)
  static Future<void> createPropertyAvailable(String userId) async {
    await _notificationService.createNotification(
      userId: userId,
      type: NotificationType.propertyAvailable,
      title: 'Propiedad guardada disponible',
      message: 'El departamento en Sopocachi sigue disponible',
      propertyId: null,
    );
    print('✓ Creada: Propiedad disponible (Campana Morada)');
  }

  /// Notificación 4: Nueva propiedad (Estrella Naranja ⭐)
  static Future<void> createNewProperty(String userId) async {
    await _notificationService.createNotification(
      userId: userId,
      type: NotificationType.newProperty,
      title: 'Nueva propiedad',
      message: 'Nuevo departamento en Zona Sur que te puede interesar',
      propertyId: null,
    );
    print('✓ Creada: Nueva propiedad (Estrella Naranja)');
  }

  /// Notificación 5: Mensaje general (Mensaje Gris 💬)
  static Future<void> createMessage(String userId) async {
    await _notificationService.createNotification(
      userId: userId,
      type: NotificationType.message,
      title: 'Mensaje del sistema',
      message: 'Bienvenido al sistema de notificaciones',
      propertyId: null,
    );
    print('✓ Creada: Mensaje general (Gris)');
  }

  /// Crear una notificación individual por tipo
  static Future<void> createByType(String userId, NotificationType type) async {
    switch (type) {
      case NotificationType.priceDropHome:
        await createPriceDropHome(userId);
        break;
      case NotificationType.priceDropTrend:
        await createPriceDropTrend(userId);
        break;
      case NotificationType.propertyAvailable:
        await createPropertyAvailable(userId);
        break;
      case NotificationType.newProperty:
        await createNewProperty(userId);
        break;
      case NotificationType.message:
        await createMessage(userId);
        break;
    }
  }
}
