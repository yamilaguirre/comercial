import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_modular/flutter_modular.dart';
import '../../providers/auth_provider.dart';
import '../../theme/theme.dart';
import '../../services/location_service.dart';
import '../../services/profile_views_service.dart';
import '../../widgets/republish_worker_button.dart';
import 'package:chaski_comercial/services/ad_service.dart';

class WorkerProfileScreen extends StatefulWidget {
  const WorkerProfileScreen({super.key});

  @override
  State<WorkerProfileScreen> createState() => _WorkerProfileScreenState();
}

class _WorkerProfileScreenState extends State<WorkerProfileScreen> {
  Future<void> _deleteWorkerProfile(String userId) async {
    try {
      // Mostrar indicador de carga
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(color: Styles.primaryColor),
          ),
        );
      }

      // Eliminar datos del perfil de trabajador en Firestore
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'profile': FieldValue.delete(),
        'professions': FieldValue.delete(),
        'price': FieldValue.delete(),
        'profession': FieldValue.delete(),
      });

      // Cerrar indicador de carga
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Mostrar mensaje de éxito
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil de trabajador eliminado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Redirigir a la pantalla de registro de trabajador
      if (mounted) {
        Modular.to.pushReplacementNamed('/worker/freelance-work');
      }
    } catch (e) {
      // Cerrar indicador de carga
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Mostrar mensaje de error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar perfil: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

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
            .collection('premium_users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, premiumSnapshot) {
          // Check if user is premium
          final isPremium =
              premiumSnapshot.hasData &&
              premiumSnapshot.data!.exists &&
              premiumSnapshot.data!.data() != null &&
              (premiumSnapshot.data!.data()
                      as Map<String, dynamic>)['status'] ==
                  'active';

          // Informar al servicio de anuncios para que omita/active interstitials
          AdService.instance.setPremiumOverride(isPremium);

          return StreamBuilder<DocumentSnapshot>(
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
                  userData?['photoUrl'] ??
                  userData?['photoURL'] ??
                  user.photoURL;

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

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .where('user_ids', arrayContains: user.uid)
                    .snapshots(),
                builder: (context, chatSnapshot) {
                  final contactsCount = chatSnapshot.data?.docs.length ?? 0;

                  return StreamBuilder<Map<String, dynamic>>(
                    stream: LocationService.calculateWorkerRatingStream(
                      user.uid,
                    ),
                    builder: (context, ratingSnapshot) {
                      final ratingData =
                          ratingSnapshot.data ?? {'rating': 0.0, 'reviews': 0};
                      final reviewsCount = ratingData['reviews'] as int;

                      return StreamBuilder<int>(
                        stream: ProfileViewsService.getViewsCountStream(
                          user.uid,
                        ),
                        builder: (context, totalViewsSnapshot) {
                          final totalViews = totalViewsSnapshot.data ?? 0;

                          // Estadísticas simuladas (ofertas y clientes por ahora estáticos)
                          final ofertas = 12;
                          final clientes = 8;

                          return SafeArea(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header con fondo premium o azul
                                  Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      gradient: isPremium
                                          ? const LinearGradient(
                                              colors: [
                                                Color(
                                                  0xFFFF6F00,
                                                ), // Vibrant Orange
                                                Color(
                                                  0xFFFFC107,
                                                ), // Vibrant Yellow
                                              ],
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                            )
                                          : LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Styles.primaryColor,
                                                Styles.primaryColor.withOpacity(
                                                  0.8,
                                                ),
                                              ],
                                            ),
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(24),
                                        bottomRight: Radius.circular(24),
                                      ),
                                    ),
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      16,
                                      20,
                                      24,
                                    ),
                                    child: Column(
                                      children: [
                                        // Settings icon
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
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
                                                                  color: Colors
                                                                      .red,
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
                                                } else if (value == 'delete_profile') {
                                                  // Confirmar eliminación de perfil de trabajador
                                                  final confirmDelete =
                                                      await showDialog<bool>(
                                                        context: context,
                                                        builder: (context) => AlertDialog(
                                                          title: const Text(
                                                            'Eliminar Perfil de Trabajador',
                                                          ),
                                                          content: const Text(
                                                            '¿Estás seguro de que deseas eliminar tu perfil de trabajador? Se eliminarán todos tus datos profesionales, portafolio y profesiones registradas. Esta acción no se puede deshacer.',
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
                                                                'Eliminar',
                                                                style: TextStyle(
                                                                  color: Colors
                                                                      .red,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );

                                                  if (confirmDelete == true) {
                                                    await _deleteWorkerProfile(user.uid);
                                                  }
                                                }
                                              },
                                              itemBuilder: (context) => [
                                                const PopupMenuItem(
                                                  value: 'delete_profile',
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.delete_forever,
                                                        color: Colors.red,
                                                      ),
                                                      SizedBox(width: 12),
                                                      Text('Eliminar Perfil Trabajador', style: TextStyle(color: Colors.red)),
                                                    ],
                                                  ),
                                                ),
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

                                        const SizedBox(height: 8),

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
                                                backgroundColor:
                                                    Colors.grey[200],
                                                backgroundImage:
                                                    photoUrl != null
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
                                                  padding: const EdgeInsets.all(
                                                    4,
                                                  ),
                                                  decoration:
                                                      const BoxDecoration(
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
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(
                                                  0.2,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(20),
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
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFF4CAF50,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
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
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            else if (userData?['verificationStatus'] ==
                                                'pending')
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange,
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
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
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            else if (userData?['verificationStatus'] ==
                                                'rejected')
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.shade400,
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
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
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            else
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withOpacity(0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
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
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // Botón de Re-publicación
                                  RepublishWorkerButton(
                                    userId: user.uid,
                                    isPremium: isPremium,
                                  ),

                                  // Botón Editar Perfil Trabajo
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          Modular.to.pushNamed(
                                            '/worker/edit-profile',
                                          );
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
                                          backgroundColor: isPremium
                                              ? const Color(
                                                  0xFFFF6F00,
                                                ) // Vibrant Orange for premium
                                              : Styles.primaryColor,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          elevation: 0,
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  // Estadísticas Generales
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: _buildDetailedStatCard(
                                            icon: Icons.visibility,
                                            iconColor: const Color(0xFFE91E63),
                                            value: totalViews.toString(),
                                            label: 'Total de visitas',
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildDetailedStatCard(
                                            icon: Icons.chat_bubble_outline,
                                            iconColor: const Color(0xFF4CAF50),
                                            value: contactsCount.toString(),
                                            label: 'Contactos recibidos',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  // Tarjeta de recomendaciones
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    child: _buildDetailedStatCard(
                                      icon: Icons.favorite,
                                      iconColor: const Color(0xFFE91E63),
                                      value: reviewsCount.toString(),
                                      label: 'Recomendación recibida',
                                    ),
                                  ),

                                  const SizedBox(height: 24),

                                  // Información de contacto
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.grey[300]!,
                                          width: 1,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                                      fontWeight:
                                                          FontWeight.w500,
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

                                  const SizedBox(height: 32),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDetailedStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
        ],
      ),
    );
  }
}
