import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_modular/flutter_modular.dart';
import '../../providers/auth_provider.dart';
import '../../theme/theme.dart';
import '../../services/location_service.dart';

class WorkerProfileScreen extends StatelessWidget {
  const WorkerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
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
          final profile = userData?['profile'] as Map<String, dynamic>?;

          final displayName =
              userData?['name'] ??
              userData?['displayName'] ??
              user.displayName ??
              'Usuario';
          final photoUrl =
              userData?['photoUrl'] ?? userData?['photoURL'] ?? user.photoURL;

          // Obtener profesión de forma segura
          String profession = 'Electricista';
          try {
            if (profile?['professions'] != null) {
              final professions = profile!['professions'] as List<dynamic>;
              if (professions.isNotEmpty) {
                final firstProf = professions[0] as Map<String, dynamic>;
                final subcategories =
                    firstProf['subcategories'] as List<dynamic>;
                if (subcategories.isNotEmpty) {
                  profession = subcategories[0].toString();
                }
              }
            }
          } catch (e) {
            // Si hay error, mantener el valor por defecto
            profession = 'Electricista';
          }

          final views = (userData?['views'] as num?)?.toInt() ?? 0;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chats')
                .where('user_ids', arrayContains: user.uid)
                .snapshots(),
            builder: (context, chatSnapshot) {
              final contactsCount = chatSnapshot.data?.docs.length ?? 0;

              return StreamBuilder<Map<String, dynamic>>(
                stream: LocationService.calculateWorkerRatingStream(user.uid),
                builder: (context, ratingSnapshot) {
                  final ratingData =
                      ratingSnapshot.data ?? {'rating': 0.0, 'reviews': 0};
                  final reviewsCount = ratingData['reviews'] as int;

                  // Estadísticas simuladas (ofertas y clientes por ahora estáticos)
                  final ofertas = 12;
                  final clientes = 8;

                  return SafeArea(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header con fondo azul
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Styles.primaryColor,
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(24),
                                bottomRight: Radius.circular(24),
                              ),
                            ),
                            padding: EdgeInsets.fromLTRB(
                              Styles.spacingMedium,
                              Styles.spacingMedium,
                              Styles.spacingMedium,
                              Styles.spacingLarge,
                            ),
                            child: Column(
                              children: [
                                // Settings icon
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    PopupMenuButton<String>(
                                      icon: const Icon(
                                        Icons.settings,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                      onSelected: (value) async {
                                        if (value == 'logout') {
                                          // Mostrar diálogo de confirmación
                                          final confirmLogout =
                                              await showDialog<bool>(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  title: const Text(
                                                    'Cerrar sesión',
                                                  ),
                                                  content: const Text(
                                                    '¿Estás seguro de que quieres cerrar sesión?',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            context,
                                                            false,
                                                          ),
                                                      child: const Text(
                                                        'Cancelar',
                                                      ),
                                                    ),
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            context,
                                                            true,
                                                          ),
                                                      child: const Text(
                                                        'Cerrar sesión',
                                                        style: TextStyle(
                                                          color: Colors.red,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );

                                          if (confirmLogout == true) {
                                            await authService.signOut();
                                            if (context.mounted) {
                                              Modular.to.navigate('/');
                                            }
                                          }
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'logout',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.logout,
                                                color: Colors.red,
                                              ),
                                              SizedBox(width: 12),
                                              Text('Cerrar sesión'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                // Avatar con badge verificado
                                Stack(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        ),
                                      ),
                                      child: CircleAvatar(
                                        radius: 45,
                                        backgroundColor: Colors.grey[200],
                                        backgroundImage: photoUrl != null
                                            ? NetworkImage(photoUrl)
                                            : null,
                                        child: photoUrl == null
                                            ? Icon(
                                                Icons.person,
                                                size: 50,
                                                color: Colors.grey[600],
                                              )
                                            : null,
                                      ),
                                    ),
                                    if (userData?['verificationStatus'] ==
                                        'verified')
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.verified,
                                            color: Color(0xFF4CAF50),
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                // Nombre
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 4),

                                // Profesión
                                Text(
                                  profession,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // Plan Gratuito y Estado de Verificación
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        'Plan Gratuito',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (userData?['verificationStatus'] ==
                                        'verified')
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4CAF50),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Icon(
                                              Icons.check_circle,
                                              color: Colors.white,
                                              size: 14,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Verificado',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else if (userData?['verificationStatus'] ==
                                        'pending')
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Icon(
                                              Icons.schedule,
                                              color: Colors.white,
                                              size: 14,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'En revisión',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else if (userData?['verificationStatus'] ==
                                        'rejected')
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade400,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Icon(
                                              Icons.error_outline,
                                              color: Colors.white,
                                              size: 14,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Rechazado',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Icon(
                                              Icons.info_outline,
                                              color: Colors.white,
                                              size: 14,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Sin verificar',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),

                                const SizedBox(height: 20),

                                // Tarjetas de estadísticas
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildStatCard(
                                        'Ofertas',
                                        ofertas.toString(),
                                        Icons.local_offer_outlined,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildStatCard(
                                        'Clientes',
                                        clientes.toString(),
                                        Icons.people_outline,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildStatCard(
                                        'Visitas',
                                        views > 1000
                                            ? '${(views / 1000).toStringAsFixed(1)}K'
                                            : views.toString(),
                                        Icons.visibility_outlined,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Botón Editar Perfil Trabajo
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: Styles.spacingMedium,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Modular.to.pushNamed('/worker/edit-profile');
                                },
                                icon: const Icon(Icons.edit, size: 20),
                                label: const Text(
                                  'Editar Perfil Trabajo',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Styles.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Estadísticas Generales
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: Styles.spacingMedium,
                            ),
                            child: const Text(
                              'Estadísticas Generales',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Tarjetas de estadísticas detalladas
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: Styles.spacingMedium,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildDetailedStatCard(
                                    icon: Icons.visibility,
                                    iconColor: const Color(0xFFE91E63),
                                    value: views.toString(),
                                    label: 'Total de visitas',
                                    trend: '+18% vs semana anterior',
                                    trendColor: const Color(0xFF4CAF50),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildDetailedStatCard(
                                    icon: Icons.chat_bubble_outline,
                                    iconColor: const Color(0xFF4CAF50),
                                    value: contactsCount.toString(),
                                    label: 'Contactos recibidos',
                                    trend: '+5 nuevos hoy',
                                    trendColor: const Color(0xFF4CAF50),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Tarjeta de recomendaciones
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: Styles.spacingMedium,
                            ),
                            child: _buildDetailedStatCard(
                              icon: Icons.favorite,
                              iconColor: const Color(0xFFE91E63),
                              value: reviewsCount.toString(),
                              label: 'Recomendación recibida',
                              trend: '+12 esta semana',
                              trendColor: const Color(0xFF4CAF50),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Información de contacto
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: Styles.spacingMedium,
                            ),
                            child: Container(
                              padding: EdgeInsets.all(Styles.spacingMedium),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Información de contacto',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      Icon(
                                        Icons.edit_outlined,
                                        size: 20,
                                        color: Colors.grey[600],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.person_outline,
                                        color: Styles.primaryColor,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Nombre completo',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            displayName,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: Styles.spacingXLarge),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required String trend,
    required Color trendColor,
  }) {
    return Container(
      padding: EdgeInsets.all(Styles.spacingMedium),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.trending_up, color: trendColor, size: 14),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  trend,
                  style: TextStyle(
                    fontSize: 11,
                    color: trendColor,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
