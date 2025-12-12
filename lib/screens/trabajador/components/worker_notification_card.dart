import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/notification_model.dart';
import '../../../core/utils/time_ago_helper.dart';
import '../../../services/notification_service.dart';
import '../../../providers/auth_provider.dart';

class WorkerNotificationCard extends StatefulWidget {
  final AppNotification notification;
  final VoidCallback? onTap;

  const WorkerNotificationCard({
    super.key,
    required this.notification,
    this.onTap,
  });

  @override
  State<WorkerNotificationCard> createState() => _WorkerNotificationCardState();
}

class _WorkerNotificationCardState extends State<WorkerNotificationCard> {
  bool _isExpanded = false;

  IconData _getIcon() {
    switch (widget.notification.type) {
      case NotificationType.priceDropHome:
        return Icons.work;
      case NotificationType.priceDropTrend:
        return Icons.trending_up;
      case NotificationType.propertyAvailable:
        return Icons.notifications;
      case NotificationType.newProperty:
        return Icons.new_releases;
      case NotificationType.message:
        return Icons.message;
      case NotificationType.premiumPropertyPublished:
        return Icons.star;
      case NotificationType.profilePasswordChanged:
        return Icons.lock;
      case NotificationType.profilePhotoChanged:
        return Icons.person;
      case NotificationType.profileNameChanged:
        return Icons.badge;
      case NotificationType.profilePhoneChanged:
        return Icons.phone;
      case NotificationType.profileEmailChanged:
        return Icons.email;
      case NotificationType.verification:
        return Icons.verified_user;
    }
  }

  Color _getIconColor() {
    switch (widget.notification.type) {
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
      case NotificationType.premiumPropertyPublished:
        return const Color(0xFFFFD700); // Dorado
      case NotificationType.profilePasswordChanged:
        return const Color(0xFFD32F2F); //Rojo oscuro
      case NotificationType.profilePhotoChanged:
        return const Color(0xFF1976D2); // Azul
      case NotificationType.profileNameChanged:
        return const Color(0xFF0097A7); // Cyan
      case NotificationType.profilePhoneChanged:
        return const Color(0xFF388E3C); // Verde
      case NotificationType.profileEmailChanged:
        return const Color(0xFFFF6F00); // Naranja oscuro
      case NotificationType.verification:
        return const Color(0xFF4CAF50); // Verde
    }
  }

  Color _getIconBackgroundColor() {
    return _getIconColor().withOpacity(0.1);
  }

  Future<void> _handleTap() async {
    setState(() {
      _isExpanded = !_isExpanded;
    });

    // Marcar como leída si no lo está
    if (!widget.notification.isRead) {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.uid ?? '';

      if (userId.isNotEmpty) {
        final notificationService = NotificationService();
        await notificationService.markAsRead(userId, widget.notification.id);
      }
    }

    // Navegar a perfil de trabajador si existe propertyId (lo usamos como workerId)
    if (widget.notification.propertyId != null &&
        widget.notification.propertyId!.isNotEmpty) {
      // Aquí podrías navegar al detalle del trabajador si es necesario
      // Modular.to.pushNamed('/worker/public-profile', arguments: workerId);
    }

    // Llamar callback si existe
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _handleTap,
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
                          widget.notification.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: widget.notification.isRead
                                ? FontWeight.normal
                                : FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      // Indicador de no leída
                      if (!widget.notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF0000FF),
                            shape: BoxShape.circle,
                          ),
                        ),
                      // Indicador de expansión
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  AnimatedCrossFade(
                    firstChild: Text(
                      widget.notification.message,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    secondChild: Text(
                      widget.notification.message,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                    crossFadeState: _isExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 200),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    TimeAgoHelper.format(widget.notification.createdAt),
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
