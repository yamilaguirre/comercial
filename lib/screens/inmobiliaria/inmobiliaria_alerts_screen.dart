import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/theme.dart';
import '../../services/notification_service.dart';
import '../../providers/auth_provider.dart';
import '../../models/notification_model.dart';
import '../property/components/notification_card.dart';

class InmobiliariaAlertsScreen extends StatefulWidget {
  const InmobiliariaAlertsScreen({super.key});

  @override
  State<InmobiliariaAlertsScreen> createState() =>
      _InmobiliariaAlertsScreenState();
}

class _InmobiliariaAlertsScreenState extends State<InmobiliariaAlertsScreen> {
  final NotificationService _notificationService = NotificationService();

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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: true,
        title: Row(
          children: [
            Icon(Icons.notifications, color: Styles.primaryColor, size: 24),
            const SizedBox(width: 8),
            const Text(
              'Avisos Inmobiliaria',
              style: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          StreamBuilder<List<AppNotification>>(
            stream: _notificationService.getNotificationsForPropertyModule(
              userId,
            ),
            builder: (context, snapshot) {
              final notifications = snapshot.data ?? [];
              final unreadIds = notifications
                  .where((n) => !n.isRead)
                  .map((n) => n.id)
                  .toList();

              return TextButton(
                onPressed: unreadIds.isEmpty
                    ? null
                    : () => _markAllAsRead(userId, unreadIds),
                child: Text(
                  'Marcar todo como leído',
                  style: TextStyle(
                    color: unreadIds.isEmpty
                        ? Colors.grey
                        : Styles.primaryColor,
                    fontSize: 14,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: _notificationService.getNotificationsForPropertyModule(userId),
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
                    'Te notificaremos sobre cambios importantes',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return NotificationCard(
                  notification: notification,
                  onTap: () {
                    // Opcional: acción adicional
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
