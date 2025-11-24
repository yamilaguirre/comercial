import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/theme.dart';
import '../../providers/auth_provider.dart';

// Datos simulados para demostración
class OwnerStats {
  final int activePosts = 12;
  final int pausedPosts = 3;
  final int totalViews = 2847;
  final int contactsReceived = 47;
  final int favoritesObtained = 156;
}

class OwnerProfileScreen extends StatelessWidget {
  const OwnerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;
    final stats = OwnerStats();

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
              userData?['displayName'] ?? user.displayName ?? 'Propietario';
          final photoUrl = userData?['photoURL'] ?? user.photoURL;

          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(context, displayName, photoUrl),
              SliverList(
                delegate: SliverChildListDelegate([
                  _buildStatsOverview(context, stats),
                  _buildCtaButton(context),
                  _buildGeneralStatsGrid(stats),
                  const SizedBox(height: 32),
                  _buildManagementSection(context),
                  const SizedBox(height: 80),
                ]),
              ),
            ],
          );
        },
      ),
      // Botón flotante para crear nueva publicación
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/property/new'),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Nueva Publicación',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Styles.primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        heroTag: 'new_post_fab',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // --- WIDGETS DE BARRA SUPERIOR (HEADER) ---

  SliverAppBar _buildSliverAppBar(
    BuildContext context,
    String displayName,
    String? photoUrl,
  ) {
    return SliverAppBar(
      expandedHeight: 200.0,
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
          'Perfil de Propietario',
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
                        'Agente Inmobiliario',
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

  // --- WIDGETS DE ESTADÍSTICAS ---

  Widget _buildStatsOverview(BuildContext context, OwnerStats stats) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Styles.spacingMedium,
        vertical: Styles.spacingMedium,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatCard(
            context,
            'Activas',
            '${stats.activePosts}',
            const Color(0xFF3B82F6), // Azul
          ),
          _buildStatCard(
            context,
            'Consultas',
            '${stats.contactsReceived}',
            const Color(0xFFF97316), // Naranja
          ),
          _buildStatCard(
            context,
            'Visitas',
            '${(stats.totalViews / 1000).toStringAsFixed(1)}K',
            const Color(0xFF10B981), // Verde
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    Color color,
  ) {
    return Container(
      width:
          (MediaQuery.of(context).size.width -
              Styles.spacingLarge * 2 -
              Styles.spacingMedium * 2) /
          3,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCtaButton(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Styles.spacingMedium,
        vertical: Styles.spacingSmall,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: () => context.push('/property/new'),
          icon: const Icon(Icons.add, size: 24),
          label: const Text(
            'Crear nueva publicación',
            style: TextStyle(fontSize: 18),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Styles.primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
          ),
        ),
      ),
    );
  }

  Widget _buildGeneralStatsGrid(OwnerStats stats) {
    final List<Map<String, dynamic>> metrics = [
      {
        'icon': Icons.home_work,
        'title': 'Publicaciones activas',
        'value': stats.activePosts,
        'trend': '+2 esta semana',
        'color': Styles.primaryColor,
        'bgColor': Styles.primaryColor.withOpacity(0.1),
      },
      {
        'icon': Icons.pause_circle_outline,
        'title': 'Publicaciones pausadas',
        'value': stats.pausedPosts,
        'trend': 'Reactivar ahora',
        'color': Colors.grey,
        'bgColor': Colors.grey.shade100,
      },
      {
        'icon': Icons.remove_red_eye_outlined,
        'title': 'Total de visitas',
        'value': stats.totalViews,
        'trend': '+18% vs semana anterior',
        'color': Styles.infoColor,
        'bgColor': Styles.infoColor.withOpacity(0.1),
      },
      {
        'icon': Icons.chat_bubble_outline,
        'title': 'Contactos recibidos',
        'value': stats.contactsReceived,
        'trend': '+5 nuevos hoy',
        'color': Colors.redAccent,
        'bgColor': Colors.redAccent.withOpacity(0.1),
      },
      {
        'icon': Icons.favorite_border,
        'title': 'Favoritos obtenidos',
        'value': stats.favoritesObtained,
        'trend': '+12% este mes',
        'color': Colors.pink,
        'bgColor': Colors.pink.withOpacity(0.1),
      },
      {
        'icon': Icons.attach_money,
        'title': 'Ingreso Potencial',
        'value': 250000,
        'isCurrency': true,
        'trend': 'Según precio promedio',
        'color': Colors.green,
        'bgColor': Colors.green.withOpacity(0.1),
      },
    ];

    return Padding(
      padding: EdgeInsets.all(Styles.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estadísticas Generales',
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
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: metrics.length,
            itemBuilder: (context, index) {
              final metric = metrics[index];
              return _buildMetricCard(metric);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(Map<String, dynamic> metric) {
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(
            metric['icon'] as IconData,
            size: 28,
            color: metric['color'] as Color,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                metric['isCurrency'] == true
                    ? '\$${metric['value']}'
                    : '${metric['value']}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Styles.textPrimary,
                ),
              ),
              Text(
                metric['title'] as String,
                style: const TextStyle(
                  fontSize: 12,
                  color: Styles.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.trending_up,
                    size: 14,
                    color: metric['color'] as Color,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    metric['trend'] as String,
                    style: TextStyle(
                      fontSize: 10,
                      color: metric['color'] as Color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManagementSection(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Styles.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gestión Rápida',
            style: TextStyles.subtitle.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: Icon(Icons.list_alt, color: Styles.primaryColor),
            title: const Text('Ver Mis Publicaciones'),
            subtitle: const Text(
              'Edita y gestiona todos tus anuncios activos.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/property/my'),
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(Icons.history, color: Colors.purple),
            title: const Text('Historial de Pagos'),
            subtitle: const Text(
              'Revisa tus transacciones y suscripciones Premium.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }
}
