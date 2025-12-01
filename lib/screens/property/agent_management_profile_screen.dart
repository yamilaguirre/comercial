import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../theme/theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/agent_stats_service.dart';

import 'components/profile_header_section.dart';
import 'components/profile_components.dart';

// Pantalla para el Agente/Dueño para ver sus estadísticas y actividad.
class AgentManagementProfileScreen extends StatefulWidget {
  const AgentManagementProfileScreen({super.key});

  @override
  State<AgentManagementProfileScreen> createState() =>
      _AgentManagementProfileScreenState();
}

class _AgentManagementProfileScreenState
    extends State<AgentManagementProfileScreen> {
  final AgentStatsService _statsService = AgentStatsService();
  Map<String, dynamic> _stats = {};
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final authService = Modular.get<AuthService>();
    final user = authService.currentUser;
    if (user != null) {
      final stats = await _statsService.getAgentStats(user.uid);
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoadingStats = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Modular.get<AuthService>();
    final user = authService.currentUser;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Usamos StreamBuilder para obtener los datos del usuario en tiempo real
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData ||
            snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Styles.primaryColor),
          );
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final name =
            userData['displayName'] ?? user.displayName ?? 'Agente Mobiliaria';
        final email = userData['email'] ?? user.email ?? 'Sin correo';
        final phone = userData['phoneNumber'] ?? '+591 7XXX-XXXX';
        final photoUrl = userData['photoURL'] ?? user.photoURL;

        final headerStats = {
          'Activas': (_stats['activeProperties'] ?? 0).toString(),
          'Consultas': (_stats['totalInquiries'] ?? 0).toString(),
          'Visitas': _formatNumber(_stats['totalViews'] ?? 0),
        };

        return Scaffold(
          backgroundColor: Colors.white,
          body: Column(
            children: [
              // 1. Cabecera (Parte Constante)
              ProfileHeaderSection(
                name: name,
                role: 'Agente Inmobiliario',
                photoUrl: photoUrl,
                stats: headerStats,
                onSettingsTap: () {
                  Modular.to.pushNamed('/property/account');
                },
              ),

              // 2. Contenido Deslizable
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(Styles.spacingMedium),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Botón de Creación ---
                      Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: Styles.spacingMedium,
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              Modular.to.pushNamed('/property/new'),
                          icon: const Icon(Icons.add_circle_outline, size: 24),
                          label: const Text(
                            'Crear nueva publicación',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Styles.primaryColor,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      // --- Estadísticas Generales (Detalle) ---
                      Text(
                        'Estadísticas Generales',
                        style: TextStyles.subtitle.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: Styles.spacingMedium),
                      _isLoadingStats
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Styles.primaryColor,
                              ),
                            )
                          : _buildStatsGrid(),
                      SizedBox(height: Styles.spacingLarge),

                      // --- Información de Contacto (Editable) ---
                      _buildContactInfo(email, phone, userData),

                      SizedBox(height: Styles.spacingLarge * 2),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      mainAxisSpacing: Styles.spacingMedium,
      crossAxisSpacing: Styles.spacingMedium,
      children: [
        _buildStatTile(
          'Publicaciones activas',
          (_stats['activeProperties'] ?? 0).toString(),
          Icons.home_work_outlined,
          Styles.primaryColor,
          'Total: ${_stats['totalProperties'] ?? 0}',
        ),
        _buildStatTile(
          'Publicaciones pausadas',
          (_stats['pausedProperties'] ?? 0).toString(),
          Icons.pause_circle_outline,
          Colors.orange,
          'Inactivas',
        ),
        _buildStatTile(
          'Total de visitas',
          _formatNumber(_stats['totalViews'] ?? 0),
          Icons.visibility_outlined,
          Colors.purple,
          'Todas tus propiedades',
        ),
        _buildStatTile(
          'Contactos recibidos',
          (_stats['totalInquiries'] ?? 0).toString(),
          Icons.chat_bubble_outline,
          Colors.teal,
          'Consultas por chat',
        ),
        _buildStatTile(
          'Favoritos obtenidos',
          (_stats['totalFavorites'] ?? 0).toString(),
          Icons.favorite_border,
          Colors.pink,
          'Guardados por usuarios',
        ),
      ],
    );
  }

  Widget _buildStatTile(
    String label,
    String value,
    IconData icon,
    Color color,
    String subtext,
  ) {
    return Container(
      padding: EdgeInsets.all(Styles.spacingMedium),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyles.title.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyles.caption.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                subtext,
                style: TextStyles.caption.copyWith(
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Información de Contacto (image_3decb0.png)
  Widget _buildContactInfo(
    String email,
    String phone,
    Map<String, dynamic> userData,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: Styles.spacingLarge),
      padding: EdgeInsets.all(Styles.spacingMedium),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
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
                icon: Icon(Icons.edit_outlined, color: Styles.primaryColor),
                onPressed: () {
                  // Asumo que '/property/account/edit-profile' está anidado en /account
                  Modular.to.pushNamed(
                    '/property/account/edit-profile',
                    arguments: userData,
                  );
                },
              ),
            ],
          ),
          ContactInfoItem(
            icon: Icons.person_outline,
            label: 'Nombre completo',
            value: userData['displayName'] ?? 'Nombre no registrado',
          ),
          const Divider(),
          ContactInfoItem(
            icon: Icons.phone_outlined,
            label: 'Teléfono',
            value: phone,
            isEditable: true, // Indica que al tocar puede editar o interactuar
            onTap: () {
              // Lógica de edición
            },
          ),
          const Divider(),
          ContactInfoItem(
            icon: Icons.email_outlined,
            label: 'Correo electrónico',
            value: email,
            isEditable: true, // Indica que al tocar puede editar o interactuar
            onTap: () {
              // Lógica de edición
            },
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}
