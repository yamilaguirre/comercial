import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart'; // Importación de Modular
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../theme/theme.dart';
import '../../providers/mobiliaria_provider.dart'; // Importación necesaria

// Importamos los nuevos componentes
import 'components/account_header.dart';
import 'components/account_menu_section.dart';

class PropertyAccountScreen extends StatefulWidget {
  const PropertyAccountScreen({super.key});

  @override
  State<PropertyAccountScreen> createState() => _PropertyAccountScreenState();
}

class _PropertyAccountScreenState extends State<PropertyAccountScreen> {
  bool showPremiumModal = false;

  // --- FUNCIÓN: CAMBIAR DE MÓDULO (REDIRECCIÓN A SELECCIÓN DE ROL) ---
  void _changeModule() async {
    final authService = Modular.get<AuthService>();
    final user = authService.currentUser;

    if (user == null) {
      Modular.to.navigate('/login');
      return;
    }

    try {
      Modular.to.navigate('/worker/home-worker');
    } catch (e) {}
  }

  // --- Opciones de Gestión de Propiedades (ESTÁTICAS) ---
  List<Widget> _buildPropertyManagementItems() {
    return [
      AccountMenuItem(
        icon: Icons.add_home_work,
        iconColor: Styles.primaryColor,
        iconBgColor: Styles.primaryColor.withOpacity(0.1),
        title: 'Publicar nueva propiedad',
        subtitle: 'Crea un anuncio de venta/alquiler',
        onTap: () => Modular.to.pushNamed('/property/new'),
      ),
      AccountMenuSection.buildDivider(),
      AccountMenuItem(
        icon: Icons.edit_note,
        iconColor: Colors.blue,
        iconBgColor: Colors.blue.withOpacity(0.1),
        title: 'Mis Publicaciones',
        subtitle: 'Edita o elimina tus anuncios',
        onTap: () => Modular.to.pushNamed('/property/my'),
      ),
    ];
  }

  // --- Menú General (Extraído para limpieza) ---
  Widget _buildGeneralMenu(Map<String, dynamic>? userData) {
    return AccountMenuSection(
      hasTitle: false, // No necesita título de sección
      items: [
        AccountMenuItem(
          icon: Icons.person_outline,
          iconColor: const Color(0xFF6B7280),
          iconBgColor: const Color(0xFFF3F4F6),
          title: 'Editar perfil',
          subtitle: 'Actualiza tu información personal',
          onTap: () => Modular.to.pushNamed(
            '/property/edit-profile',
            arguments: userData,
          ),
        ),

        AccountMenuSection.buildDivider(),

        // NUEVO: Ver Perfil de Gestión (Vista interna del Agente/Dueño)
        AccountMenuItem(
          icon: Icons.leaderboard_outlined,
          iconColor: Colors.indigo.shade600,
          iconBgColor: Colors.indigo.shade600.withOpacity(0.1),
          title: 'Ver Perfil de Gestión',
          subtitle: 'Accede a tus estadísticas completas y herramientas',
          onTap: () =>
              Modular.to.pushNamed('/property/agent-management-profile'),
        ),

        AccountMenuSection.buildDivider(),

        // NUEVO: Ver Perfil Público (Vista del Cliente)
        AccountMenuItem(
          icon: Icons.visibility_outlined,
          iconColor: Colors.teal.shade600,
          iconBgColor: Colors.teal.shade600.withOpacity(0.1),
          title: 'Ver Perfil Público',
          subtitle: 'Simula cómo ven tu perfil los clientes',
          onTap: () => Modular.to.pushNamed('/property/public-profile'),
        ),

        AccountMenuSection.buildDivider(),

        AccountMenuItem(
          icon: Icons.workspace_premium,
          iconColor: const Color(0xFFFFB800),
          iconBgColor: const Color(0xFFFFF7E6),
          title: 'Suscripción Premium',
          subtitle: 'Desbloquea funciones exclusivas',
          onTap: () => setState(() => showPremiumModal = true),
        ),
        AccountMenuSection.buildDivider(),
        AccountMenuItem(
          icon: Icons.settings_outlined,
          iconColor: const Color(0xFF6B7280),
          iconBgColor: const Color(0xFFF3F4F6),
          title: 'Configuración',
          subtitle: 'Preferencias y notificaciones',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Próximamente: Configuración')),
            );
          },
        ),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await authService.signOut();
              Modular.to.navigate('/');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }

  // --- WIDGET PRINCIPAL BUILD ---

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    if (user == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Cuenta'),
        backgroundColor: Styles.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Escuchamos cambios en tiempo real del usuario
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.active) {
                return const Center(
                  child: CircularProgressIndicator(color: Styles.primaryColor),
                );
              }

              final userData = snapshot.data!.data() as Map<String, dynamic>?;

              final displayName =
                  userData?['displayName'] ?? user.displayName ?? 'Usuario';
              final email = userData?['email'] ?? user.email ?? 'Sin correo';
              final photoUrl = userData?['photoURL'] ?? user.photoURL;
              final userRole = userData?['role'] ?? 'cliente';

              // ----------------------------------------------------
              // 1. Opciones de Gestión (Propiedades + Botón de Módulo)
              // ----------------------------------------------------
              final List<Widget> managementItems = [];

              // Añadir el botón de CAMBIAR MÓDULO (si el rol actual no es solo 'cliente' o si queremos que siempre esté disponible)
              // Lo mantendremos visible si el rol es 'inmobiliaria' o 'cliente' para darle la opción de ir a trabajador.

              managementItems.insertAll(0, [
                AccountMenuItem(
                  icon: Icons.swap_horiz, // Ícono genérico de cambio
                  iconColor: Styles.infoColor,
                  iconBgColor: Styles.infoColor.withOpacity(0.1),
                  title: 'Cambiar de Módulo', // Título actualizado
                  subtitle:
                      'Ir a la selección de rol (Inmobiliaria/Trabajador)',
                  onTap: _changeModule, // Llama a la nueva función
                ),
                AccountMenuSection.buildDivider(),
              ]);

              // Añadir opciones de gestión de propiedades (son estáticas ahora)
              managementItems.addAll(_buildPropertyManagementItems());

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // A. Header (Componente externo)
                    AccountHeader(
                      displayName: displayName,
                      email: email,
                      photoUrl: photoUrl,
                      userRole: userRole,
                    ),

                    // B. Opciones de Gestión (Módulo Propiedades + Botón de Cambio)
                    AccountMenuSection(
                      title: 'Gestión de Propiedades',
                      items: managementItems,
                    ),

                    // C. Menú General (Componente externo)
                    _buildGeneralMenu(userData),

                    // D. Botón Cerrar sesión (Mantenido aquí por el widget TextButton)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: Styles.spacingMedium,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () =>
                              _showLogoutDialog(context, authService),
                          icon: const Icon(
                            Icons.logout,
                            color: Color(0xFFEF4444),
                            size: 20,
                          ),
                          label: const Text(
                            'Cerrar sesión',
                            style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: Styles.spacingMedium,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: Styles.spacingLarge),
                  ],
                ),
              );
            },
          ),

          // Modal Premium
          if (showPremiumModal) _buildPremiumModal(),
        ],
      ),
    );
  }

  // Se mantienen solo los widgets auxiliares no transferidos (Modal y Dialogo)
  Widget _buildPremiumModal() {
    // Código de _buildPremiumModal sin cambios
    return GestureDetector(
      onTap: () => setState(() => showPremiumModal = false),
      child: Container(
        color: Colors.black.withOpacity(0.5),
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () {},
          child: Container(
            margin: EdgeInsets.all(Styles.spacingLarge),
            padding: EdgeInsets.all(Styles.spacingLarge),
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFF6B00),
                  Color(0xFFFF8C00),
                  Color(0xFFFF3B9A),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'VIP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => showPremiumModal = false),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
                const Icon(
                  Icons.workspace_premium,
                  color: Colors.white,
                  size: 60,
                ),
                SizedBox(height: Styles.spacingMedium),
                const Text(
                  'Hazte Premium',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Accede a más resultados y\nfunciones exclusivas',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                SizedBox(height: Styles.spacingLarge),
                ElevatedButton(
                  onPressed: () => setState(() => showPremiumModal = false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFFF6B00),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Suscribirme ahora',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
