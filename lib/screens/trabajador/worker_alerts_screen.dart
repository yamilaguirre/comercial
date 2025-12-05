import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/theme.dart';
import '../../services/notification_service.dart';
import '../../providers/auth_provider.dart';
import '../../models/notification_model.dart';
import 'components/worker_notification_card.dart';

class WorkerAlertsScreen extends StatefulWidget {
  const WorkerAlertsScreen({super.key});

  @override
  State<WorkerAlertsScreen> createState() => _WorkerAlertsScreenState();
}

class _WorkerAlertsScreenState extends State<WorkerAlertsScreen> {
  final NotificationService _notificationService = NotificationService();
  bool _hasMarkedAsRead = false;

  Future<void> _markAllAsRead(
    String userId,
    List<String> notificationIds,
  ) async {
    if (notificationIds.isEmpty) return;

    final success = await _notificationService.markAllAsRead(
      userId,
      notificationIds,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Todas las notificaciones marcadas como leídas'
                : 'Error al marcar notificaciones',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final userId = authService.currentUser?.uid ?? '';
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications, color: Styles.primaryColor, size: 24),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Notificaciones',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          StreamBuilder<List<AppNotification>>(
            stream: _notificationService.getWorkerNotifications(userId),
            builder: (context, snapshot) {
              final notifications = snapshot.data ?? [];
              final unreadIds = notifications
                  .where((n) => !n.isRead)
                  .map((n) => n.id)
                  .toList();

              return Flexible(
                child: TextButton(
                  onPressed: unreadIds.isEmpty
                      ? null
                      : () => _markAllAsRead(userId, unreadIds),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 8 : 12,
                    ),
                  ),
                  child: Text(
                    isSmallScreen ? 'Marcar leído' : 'Marcar todo como leído',
                    style: TextStyle(
                      color: unreadIds.isEmpty
                          ? Colors.grey
                          : Styles.primaryColor,
                      fontSize: isSmallScreen ? 12 : 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: _notificationService.getWorkerNotifications(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error al cargar notificaciones',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            );
          }

          final notifications = snapshot.data ?? [];

          // Marcar automáticamente como leídas al cargar la pantalla (solo una vez)
          if (!_hasMarkedAsRead && notifications.isNotEmpty) {
            _hasMarkedAsRead = true;
            final unreadIds = notifications
                .where((n) => !n.isRead)
                .map((n) => n.id)
                .toList();
            if (unreadIds.isNotEmpty) {
              // Marcar como leídas en background sin mostrar snackbar
              Future.microtask(
                () => _notificationService.markAllAsRead(userId, unreadIds),
              );
            }
          }

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No tienes notificaciones',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Te notificaremos sobre oportunidades de trabajo',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              // El StreamBuilder se actualiza automáticamente
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return WorkerNotificationCard(
                  notification: notification,
                  onTap: () {
                    // Opcional: acción adicional al hacer tap
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
