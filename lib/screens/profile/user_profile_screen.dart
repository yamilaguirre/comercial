import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/theme.dart';
import '../../providers/auth_provider.dart';

// Datos simulados para demostración
class UserStats {
  final int viewedProperties = 145;
  final int savedFavorites = 23;
  final int contactAttempts = 8;
  final String mostAttractiveZone = 'Sopocachi, La Paz';
}

class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;
    final stats = UserStats();

    if (user == null)
      return const Center(child: Text('Error de autenticación'));

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Styles.primaryColor),
            );
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          final displayName =
              userData?['displayName'] ?? user.displayName ?? 'Usuario';
          final photoUrl = userData?['photoURL'] ?? user.photoURL;
          final email = userData?['email'] ?? user.email ?? 'Sin correo';
          final phone = userData?['phoneNumber'] ?? 'Sin número';

          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(context, displayName, photoUrl),
              SliverList(
                delegate: SliverChildListDelegate([
                  _buildContactInfo(context, displayName, phone, email),
                  _buildActivitySection(context, stats),
                  _buildRecentActivity(),
                  const SizedBox(height: 80),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- WIDGETS DE BARRA SUPERIOR (HEADER) ---

  SliverAppBar _buildSliverAppBar(
    BuildContext context,
    String displayName,
    String? photoUrl,
  ) {
    return SliverAppBar(
      expandedHeight: 180.0,
      floating: false,
      pinned: true,
      backgroundColor: Styles.primaryColor,
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.white,
          size: 20,
        ),
        onPressed: () => context.go('/account'),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.white),
          onPressed: () => context.push('/account'),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 16.0, bottom: 16.0),
        title: Text(
          'Perfil de Usuario',
          style: TextStyles.title.copyWith(color: Colors.white, fontSize: 18),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Styles.primaryColor,
                Styles.primaryColor.withOpacity(0.9),
              ],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 50,
              left: Styles.spacingLarge,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  backgroundImage: photoUrl != null
                      ? NetworkImage(photoUrl)
                      : null,
                  child: photoUrl == null
                      ? Text(
                          displayName[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 24,
                            color: Styles.primaryColor,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyles.title.copyWith(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Buscador Activo',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGETS DE CONTENIDO ---

  Widget _buildContactInfo(
    BuildContext context,
    String name,
    String phone,
    String email,
  ) {
    return Padding(
      padding: EdgeInsets.all(Styles.spacingMedium),
      child: Container(
        padding: EdgeInsets.all(Styles.spacingMedium),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Información de contacto',
                  style: TextStyles.subtitle.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => context.push('/edit-profile'),
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: Styles.primaryColor,
                  ),
                ),
              ],
            ),
            const Divider(),
            _buildContactRow(Icons.person_outline, 'Nombre completo', name),
            _buildContactRow(Icons.phone_outlined, 'Teléfono', phone),
            _buildContactRow(Icons.email_outlined, 'Correo electrónico', email),
          ],
        ),
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Styles.textSecondary, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyles.caption.copyWith(color: Styles.textSecondary),
              ),
              Text(
                value,
                style: TextStyles.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySection(BuildContext context, UserStats stats) {
    final List<Map<String, dynamic>> activityMetrics = [
      {
        'icon': Icons.remove_red_eye_outlined,
        'title': 'Propiedades Vistas',
        'value': stats.viewedProperties,
        'color': Styles.infoColor,
      },
      {
        'icon': Icons.favorite_border,
        'title': 'Propiedades Guardadas',
        'value': stats.savedFavorites,
        'color': Colors.pink,
      },
      {
        'icon': Icons.phone_in_talk_outlined,
        'title': 'Intentos de Contacto',
        'value': stats.contactAttempts,
        'color': Colors.redAccent,
      },
    ];

    return Padding(
      padding: EdgeInsets.all(Styles.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estadísticas de Búsqueda',
            style: TextStyles.subtitle.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.0,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: activityMetrics.length,
            itemBuilder: (context, index) {
              final metric = activityMetrics[index];
              return _buildActivityMetricCard(metric);
            },
          ),
          const SizedBox(height: 20),
          _buildFavoriteZoneCard(stats),
        ],
      ),
    );
  }

  Widget _buildActivityMetricCard(Map<String, dynamic> metric) {
    return Container(
      padding: EdgeInsets.all(Styles.spacingSmall),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            metric['icon'] as IconData,
            size: 30,
            color: metric['color'] as Color,
          ),
          const SizedBox(height: 4),
          Text(
            '${metric['value']}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Styles.textPrimary,
            ),
          ),
          Text(
            metric['title'] as String,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: Styles.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteZoneCard(UserStats stats) {
    return Container(
      padding: EdgeInsets.all(Styles.spacingMedium),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.pin_drop, color: Styles.primaryColor, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tu Zona Favorita',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Styles.textPrimary,
                  ),
                ),
                Text(
                  stats.mostAttractiveZone,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Styles.primaryColor,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.trending_up, color: Styles.primaryColor),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    // Simulación de actividad reciente
    final List<Map<String, String>> activities = [
      {
        'icon': 'chat',
        'title': 'Casa en Calacoto',
        'subtitle': 'Mensaje nuevo de Propietario',
        'time': 'Hace 5 min',
      },
      {
        'icon': 'favorite',
        'title': 'Departamento en Sopocachi',
        'subtitle': 'Guardado en Favoritos',
        'time': 'Hace 1 hora',
      },
      {
        'icon': 'visibility',
        'title': 'Suite en San Miguel',
        'subtitle': '24 vistas nuevas',
        'time': 'Hoy',
      },
      {
        'icon': 'notifications',
        'title': 'Alerta de Precio',
        'subtitle': 'El precio ha bajado!',
        'time': 'Ayer',
      },
    ];

    return Padding(
      padding: EdgeInsets.all(Styles.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Actividad Reciente',
            style: TextStyles.subtitle.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activities.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, indent: 60, endIndent: 16),
              itemBuilder: (context, index) {
                final activity = activities[index];
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Styles.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getIconForActivity(activity['icon']!),
                      color: Styles.primaryColor,
                      size: 24,
                    ),
                  ),
                  title: Text(
                    activity['title']!,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    activity['subtitle']!,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  trailing: Text(
                    activity['time']!,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  onTap: () {},
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () {},
              child: const Text(
                'Ver toda la actividad',
                style: TextStyle(
                  color: Styles.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForActivity(String key) {
    switch (key) {
      case 'chat':
        return Icons.chat_bubble_outline;
      case 'favorite':
        return Icons.favorite_border;
      case 'visibility':
        return Icons.remove_red_eye_outlined;
      case 'notifications':
        return Icons.notifications_none;
      default:
        return Icons.info_outline;
    }
  }
}
