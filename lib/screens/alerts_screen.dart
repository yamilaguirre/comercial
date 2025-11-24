import 'package:flutter/material.dart';
import '../theme/theme.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  // Lista de avisos/notificaciones
  final List<Map<String, dynamic>> alerts = [
    {
      'icon': Icons.home,
      'iconColor': Color(0xFF6366F1), // Morado/Indigo
      'title': 'Rebaja de precio',
      'description': 'La casa en Calacoto bajó a 1,950,000 Bs',
      'time': 'Hace 1h',
      'isUnread': true,
    },
    {
      'icon': Icons.trending_down,
      'iconColor': Color(0xFF10B981), // Verde
      'title': 'Rebaja de precio',
      'description': 'La casa en Calacoto bajó a 1,950,000 Bs',
      'time': 'Hace 1h',
      'isUnread': true,
    },
    {
      'icon': Icons.trending_down,
      'iconColor': Color(0xFF10B981), // Verde
      'title': 'Rebaja de precio',
      'description': 'Casa en San Miguel: ahora 890,000 Bs',
      'time': 'Hace 2d',
      'isUnread': true,
    },
    {
      'icon': Icons.favorite,
      'iconColor': Color(0xFFEC4899), // Rosa
      'title': 'Propiedad guardada disponible',
      'description': 'El departamento en Sopocachi sigue disponible',
      'time': 'Ayer',
      'isUnread': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.notifications, color: Styles.primaryColor, size: 24),
            SizedBox(width: Styles.spacingSmall),
            Text(
              'Avisos',
              style: TextStyles.title.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Styles.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Marcar todos como leídos
              setState(() {
                for (var alert in alerts) {
                  alert['isUnread'] = false;
                }
              });
            },
            child: Text(
              'Marcar todo como leído',
              style: TextStyle(
                color: Styles.primaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      body: alerts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  SizedBox(height: Styles.spacingMedium),
                  Text(
                    'No tienes avisos',
                    style: TextStyles.subtitle.copyWith(
                      color: Styles.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: alerts.length,
              itemBuilder: (context, index) {
                return _buildAlertItem(alerts[index]);
              },
            ),
    );
  }

  Widget _buildAlertItem(Map<String, dynamic> alert) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Marcar como leído al tocar
            setState(() {
              alert['isUnread'] = false;
            });
          },
          child: Padding(
            padding: EdgeInsets.all(Styles.spacingMedium),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icono con fondo de color
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: alert['iconColor'].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    alert['icon'],
                    color: alert['iconColor'],
                    size: 24,
                  ),
                ),
                
                SizedBox(width: Styles.spacingMedium),
                
                // Contenido del aviso
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              alert['title'],
                              style: TextStyles.body.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Styles.textPrimary,
                              ),
                            ),
                          ),
                          if (alert['isUnread'])
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Styles.primaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: Styles.spacingXSmall),
                      Text(
                        alert['description'],
                        style: TextStyles.body.copyWith(
                          fontSize: 14,
                          color: Styles.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: Styles.spacingXSmall),
                      Text(
                        alert['time'],
                        style: TextStyles.caption.copyWith(
                          fontSize: 12,
                          color: Styles.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
