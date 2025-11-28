import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:provider/provider.dart';
import '../../../models/notification_model.dart';
import '../../../core/utils/time_ago_helper.dart';
import '../../../services/notification_service.dart';
import '../../../providers/auth_provider.dart';

class NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback? onTap;

  const NotificationCard({super.key, required this.notification, this.onTap});

  IconData _getIcon() {
    switch (notification.type) {
      case NotificationType.priceDropHome:
        return Icons.home;
      case NotificationType.priceDropTrend:
        return Icons.trending_down;
      case NotificationType.propertyAvailable:
        return Icons.notifications;
      case NotificationType.newProperty:
        return Icons.new_releases;
      case NotificationType.message:
        return Icons.message;
    }
  }

  Color _getIconColor() {
    switch (notification.type) {
      case NotificationType.priceDropHome:
        return const Color(0xFF0000FF); // Azul
      case NotificationType.priceDropTrend:
        return const Color(0xFF00C853); // Verde
      case NotificationType.propertyAvailable:
        return const Color(0xFF9C27B0); // Morado
      case NotificationType.newProperty:
        return const Color(0xFFFF9800); // Naranja
      case NotificationType.message:
        return const Color(0xFF757575); // Gris
    }
  }

  Color _getIconBackgroundColor() {
    return _getIconColor().withOpacity(0.1);
  }

  Future<void> _handleTap(BuildContext context) async {
    // Marcar como leída si no lo está
    if (!notification.isRead) {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.uid ?? '';

      if (userId.isNotEmpty) {
        final notificationService = NotificationService();
        await notificationService.markAsRead(userId, notification.id);
      }
    }

    // Navegar a detalle de propiedad si existe propertyId
    if (notification.propertyId != null &&
        notification.propertyId!.isNotEmpty) {
      Modular.to.pushNamed('/property/detail/${notification.propertyId}');
    }

    // Llamar callback si existe
    onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _handleTap(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Colors.grey[200]!, width: 1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icono
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _getIconBackgroundColor(),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(_getIcon(), color: _getIconColor(), size: 24),
            ),
            const SizedBox(width: 12),

            // Contenido
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: notification.isRead
                                ? FontWeight.normal
                                : FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      // Indicador de no leída
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF0000FF),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    TimeAgoHelper.format(notification.createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
