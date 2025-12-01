import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../theme/theme.dart';
import '../../../providers/auth_provider.dart';

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
  // Simulación de datos de estadísticas y actividad
  final Map<String, String> _mockStats = {
    'Activas': '12',
    'Consultas': '8',
    'Visitas': '2.8K',
  };

  final List<Map<String, dynamic>> _mockActivity = [
    {
      'title': 'Casa en Calacoto',
      'subtitle': 'Mensaje de María G.',
      'time': 'Hace 5 min',
      'icon': Icons.chat_bubble_outline,
      'color': Styles.infoColor,
    },
    {
      'title': 'Departamento en Sopocachi',
      'subtitle': 'Favorito de 3 personas',
      'time': 'Hace 1 hora',
      'icon': Icons.favorite_border,
      'color': Colors.red,
    },
    {
      'title': 'Suite en San Miguel',
      'subtitle': '24 visitas nuevas',
      'time': 'Hoy',
      'icon': Icons.visibility_outlined,
      'color': Styles.primaryColor,
    },
    {
      'title': 'Casa en Calacoto',
      'subtitle': 'Mensaje de Jorge L.',
      'time': 'Ayer',
      'icon': Icons.chat_bubble_outline,
      'color': Styles.infoColor,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final authService = Modular.get<AuthService>();
    final user = authService.currentUser;

    if (user == null) {
      // Redirigir si no hay usuario
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

        return Scaffold(
          backgroundColor: Colors.white,
          body: Column(
            children: [
              // 1. Cabecera (Parte Constante)
              ProfileHeaderSection(
                name: name,
                role:
                    'Agente Inmobiliario', // Rol fijo para esta vista de gestión
                photoUrl: photoUrl,
                stats: _mockStats,
                onSettingsTap: () {
                  // Navegar a la configuración de la cuenta (Ya existe en PropertyAccountScreen)
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
                      _buildStatsGrid(),
                      SizedBox(height: Styles.spacingLarge),

                      // --- Información de Contacto (Editable) ---
                      _buildContactInfo(email, phone, userData),

                      SizedBox(height: Styles.spacingLarge),

                      // --- Actividad Reciente ---
                      Text(
                        'Actividad Reciente',
                        style: TextStyles.subtitle.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: Styles.spacingMedium),
                      _buildRecentActivity(),

                      // Botón para ver toda la actividad
                      TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Cargando historial de actividad...',
                              ),
                            ),
                          );
                        },
                        child: Text(
                          'Ver toda la actividad',
                          style: TextStyle(
                            color: Styles.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

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

  // Grid de Estadísticas Detalladas (image_3decd4.png)
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
          '12',
          Icons.home_work_outlined,
          Styles.primaryColor,
          '+2 esta semana',
        ),
        _buildStatTile(
          'Publicaciones pausadas',
          '3',
          Icons.pause_circle_outline,
          Colors.orange,
          'Ver detalles',
        ),
        _buildStatTile(
          'Total de visitas',
          '2,847',
          Icons.visibility_outlined,
          Colors.purple,
          '+18% vs semana anterior',
        ),
        _buildStatTile(
          'Contactos recibidos',
          '47',
          Icons.chat_bubble_outline,
          Colors.teal,
          '+5 nuevos hoy',
        ),
        _buildStatTile(
          'Favoritos obtenidos',
          '156',
          Icons.favorite_border,
          Colors.pink,
          '+3 esta semana',
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

  // Lista de Actividad Reciente
  Widget _buildRecentActivity() {
    return Column(
      children: _mockActivity.map((activity) {
        return ProfileActivityItem(
          title: activity['title'],
          subtitle: activity['subtitle'],
          time: activity['time'],
          icon: activity['icon'],
          iconColor: activity['color'],
        );
      }).toList(),
    );
  }
}
