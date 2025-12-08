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
import 'premium_subscription_modal.dart';

class PropertyAccountScreen extends StatefulWidget {
  const PropertyAccountScreen({super.key});

  @override
  State<PropertyAccountScreen> createState() => _PropertyAccountScreenState();
}

class _PropertyAccountScreenState extends State<PropertyAccountScreen> {
  // --- FUNCIÓN: MANEJAR SUSCRIPCIÓN PREMIUM ---
  Future<void> _handlePremiumSubscription() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    if (user == null) return;

    try {
      // 1. Verificar si ya es premium en la colección premium_users
      final premiumDoc = await FirebaseFirestore.instance
          .collection('premium_users')
          .doc(user.uid)
          .get();

      if (premiumDoc.exists && premiumDoc.data()?['status'] == 'active') {
        // Ya es premium -> Ir a estado
        Modular.to.pushNamed('/property/subscription-status');
        return;
      }

      // 2. Verificar si tiene solicitud pendiente
      final requestsQuery = await FirebaseFirestore.instance
          .collection('subscription_requests')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (requestsQuery.docs.isNotEmpty) {
        // Si tiene solicitud (pendiente, aprobada o rechazada) -> Ir a estado
        Modular.to.pushNamed('/property/subscription-status');
      } else {
        // No tiene nada -> Mostrar Modal Premium
        showDialog(
          context: context,
          builder: (context) => const PremiumSubscriptionModal(),
        );
      }
    } catch (e) {
      print('Error checking subscription: $e');
      // En caso de error, ir a la pantalla de estado que manejará la carga
      Modular.to.pushNamed('/property/subscription-status');
    }
  }

  // --- FUNCIÓN: CAMBIAR DE MÓDULO (REDIRECCIÓN A TRABAJADOR) ---
  void _changeModule() async {
    final authService = Modular.get<AuthService>();
    final user = authService.currentUser;

    if (user == null) {
      Modular.to.navigate('/login');
      return;
    }

    try {
      // Cambiar el rol del usuario a 'trabajo' antes de navegar
      await authService.updateUserRole('trabajo');
      // Navegar al módulo de trabajador
      Modular.to.navigate('/worker/home-worker');
    } catch (e) {
      print('Error al cambiar de módulo: $e');
    }
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
          onTap: () {
            final user = Modular.get<AuthService>().currentUser;
            if (user != null) {
              Modular.to.pushNamed(
                '/property/public-profile',
                arguments: user.uid,
              );
            }
          },
        ),

        AccountMenuSection.buildDivider(),

        AccountMenuItem(
          icon: Icons.verified_user_outlined,
          iconColor: const Color(0xFF4CAF50),
          iconBgColor: const Color(0xFFE8F5E9),
          title: 'Solicitar Verificado',
          subtitle: 'Verifica tu identidad y destaca',
          onTap: () => Modular.to.pushNamed('/property/verification'),
        ),
        AccountMenuSection.buildDivider(),

        AccountMenuItem(
          icon: Icons.workspace_premium,
          iconColor: const Color(0xFFFFB800),
          iconBgColor: const Color(0xFFFFF7E6),
          title: 'Suscripción Premium',
          subtitle: 'Desbloquea funciones exclusivas',
          onTap: _handlePremiumSubscription,
        ),
        AccountMenuSection.buildDivider(),
        AccountMenuItem(
          icon: Icons.settings_outlined,
          iconColor: const Color(0xFF6B7280),
          iconBgColor: const Color(0xFFF3F4F6),
          title: 'Configuración',
          subtitle: 'Preferencias y opciones de cuenta',
          onTap: () => _showConfigurationOptions(userData),
        ),
      ],
    );
  }

  void _showConfigurationOptions(Map<String, dynamic>? userData) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Configuración',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Preferencias'),
              subtitle: const Text('Notificaciones y privacidad'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Próximamente: Preferencias')),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text(
                'Eliminar Cuenta',
                style: TextStyle(color: Colors.red),
              ),
              subtitle: const Text('Eliminar todo de forma permanente'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteAccountDialog();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Cuenta'),
        content: const Text(
          'ADVERTENCIA: Esto eliminará permanentemente tu cuenta y todos tus datos:\n\n'
          '• Perfil de inmobiliaria\n'
          '• Propiedades publicadas\n'
          '• Chats y mensajes\n'
          '• Favoritos y guardados\n'
          '• Toda tu información\n\n'
          'Esta acción NO puede deshacerse.\n\n'
          '¿Estás ABSOLUTAMENTE seguro?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteCompleteAccount();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar Todo'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCompleteAccount() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    if (user == null) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final userId = user.uid;

      final chatsQuery = await FirebaseFirestore.instance
          .collection('chats')
          .where('user_ids', arrayContains: userId)
          .get();

      for (var chatDoc in chatsQuery.docs) {
        await chatDoc.reference.delete();
      }

      await Future.wait([
        FirebaseFirestore.instance.collection('users').doc(userId).delete(),
        FirebaseFirestore.instance
            .collection('saved_lists')
            .where('user_id', isEqualTo: userId)
            .get()
            .then((query) async {
              for (var doc in query.docs) {
                await doc.reference.delete();
              }
            }),
        FirebaseFirestore.instance
            .collection('notifications')
            .where('user_id', isEqualTo: userId)
            .get()
            .then((query) async {
              for (var doc in query.docs) {
                await doc.reference.delete();
              }
            }),
      ]);

      await user.delete();

      if (mounted) Navigator.pop(context);
      await authService.signOut();
      Modular.to.pushNamedAndRemoveUntil('/login', (p0) => false);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar cuenta: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
              // 1. Navegar primero para salir de la pantalla protegida
              Modular.to.pushNamedAndRemoveUntil('/login', (p0) => false);

              // 2. Cerrar sesión después de navegar
              // Usamos el servicio directamente ya que el contexto podría no ser válido
              Modular.get<AuthService>().signOut();
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

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          Modular.to.navigate('/property/home');
        }
      },
      child: Scaffold(
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
                    child: CircularProgressIndicator(
                      color: Styles.primaryColor,
                    ),
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
                        verificationStatus: userData?['verificationStatus'],
                        isPremium: authService.isPremium,
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
          ],
        ),
      ),
    );
  }
}
