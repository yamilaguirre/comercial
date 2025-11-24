import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../theme/theme.dart';
import '../providers/mobiliaria_provider.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool showPremiumModal = false;

  // --- FUNCIÓN: CAMBIAR ROL Y REDIRIGIR ---
  void _toggleRole(String currentRole) async {
    final authService = context.read<AuthService>();
    final user = authService.currentUser;

    if (user == null) {
      context.go('/login');
      return;
    }

    // Determinamos el nuevo rol
    final newRole = currentRole == 'inmobiliaria' ? 'trabajo' : 'inmobiliaria';

    try {
      // 1. Actualizar 'role' y 'status' en Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'role': newRole, 'status': newRole},
      );

      // 2. Mostrar mensaje de éxito rápido
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cambiando a modo: ${newRole.toUpperCase()}...'),
            backgroundColor: Styles.infoColor,
            duration: const Duration(milliseconds: 1000),
          ),
        );
      }

      // 3. Actualizar estado local de autenticación (opcional pero recomendado)
      await user.reload();
      authService.notifyListeners();

      // 4. REDIRECCIÓN EXPLÍCITA
      if (mounted) {
        if (newRole == 'inmobiliaria') {
          context.go('/property-home');
        } else {
          context.go('/work-home');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cambiar el rol: $e'),
            backgroundColor: Styles.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    // Si no hay usuario logueado, retornamos loading
    if (user == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
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
              if (!snapshot.hasData) {
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

              // Lógica del botón de cambio
              final targetRole = userRole == 'inmobiliaria'
                  ? 'trabajo'
                  : 'inmobiliaria';
              final targetRoleDisplay = targetRole == 'trabajo'
                  ? 'Trabajador/Servicios'
                  : 'Inmobiliaria/Propiedades';
              final canToggleRole = userRole != 'cliente';

              return SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Header con degradado
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Styles.primaryColor,
                              Styles.primaryColor.withOpacity(0.8),
                            ],
                          ),
                        ),
                        child: Column(
                          children: [
                            SizedBox(height: Styles.spacingLarge),

                            // Avatar
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.grey[200],
                                backgroundImage: photoUrl != null
                                    ? NetworkImage(photoUrl)
                                    : null,
                                child: photoUrl == null
                                    ? Text(
                                        displayName.isNotEmpty
                                            ? displayName[0].toUpperCase()
                                            : 'U',
                                        style: TextStyle(
                                          fontSize: 40,
                                          color: Styles.primaryColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                            ),

                            SizedBox(height: Styles.spacingMedium),

                            // Nombre
                            Text(
                              displayName,
                              style: TextStyles.title.copyWith(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),

                            SizedBox(height: Styles.spacingXSmall),

                            // Email y Rol actual
                            Column(
                              children: [
                                Text(
                                  email,
                                  style: TextStyles.body.copyWith(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Text(
                                    userRole == 'cliente'
                                        ? 'ROL NO DEFINIDO'
                                        : userRole.toString().toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: Styles.spacingMedium),

                            // Badge Plan Gratuito
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.workspace_premium_outlined,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Plan Gratuito',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: Styles.spacingLarge),
                          ],
                        ),
                      ),

                      // BOTÓN PARA CAMBIAR DE ROL (ESTILOS MEJORADOS)
                      if (canToggleRole)
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            Styles.spacingMedium,
                            Styles.spacingMedium,
                            Styles.spacingMedium,
                            Styles.spacingXSmall,
                          ),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              // Degradado de colores vibrantes
                              gradient: const LinearGradient(
                                colors: [Styles.infoColor, Color(0xFF14B8A6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              // Sombra de botón
                              boxShadow: [
                                BoxShadow(
                                  color: Styles.infoColor.withOpacity(0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () => _toggleRole(userRole),
                              icon: const Icon(
                                Icons.swap_horiz,
                                size: 24,
                              ), // Icono de cambio
                              label: Text(
                                'Cambiar a modo ${targetRoleDisplay.toUpperCase()}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors
                                    .transparent, // Fondo transparente para mostrar el degradado
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0, // Quitamos la elevación base
                              ),
                            ),
                          ),
                        ),

                      // SECCIÓN DE BOTONES DE PERFIL DE ACTIVIDAD
                      Container(
                        margin: EdgeInsets.all(Styles.spacingMedium),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
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
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                Styles.spacingMedium,
                                Styles.spacingMedium,
                                Styles.spacingMedium,
                                Styles.spacingXSmall,
                              ),
                              child: Text(
                                'Perfiles de Actividad',
                                style: TextStyles.subtitle.copyWith(
                                  color: Styles.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            // Botón 1: Perfil de Propietario (Estadísticas Inmobiliarias)
                            _buildMenuItem(
                              icon: Icons.bar_chart,
                              iconColor: Styles.primaryColor,
                              iconBgColor: Styles.primaryColor.withOpacity(0.1),
                              title: 'Perfil de Propietario',
                              subtitle: 'Estadísticas de tus publicaciones',
                              onTap: () => context.push('/profile/owner'),
                            ),
                            _buildDivider(),

                            // Botón 2: Perfil de Usuario (Estadísticas de Consumo)
                            _buildMenuItem(
                              icon: Icons.person_search,
                              iconColor: Colors.blue,
                              iconBgColor: Colors.blue.withOpacity(0.1),
                              title: 'Perfil de Usuario',
                              subtitle:
                                  'Tus preferencias y actividad de búsqueda',
                              onTap: () => context.push('/profile/user'),
                            ),

                            // No incluimos 'Ver Mis Publicaciones' y 'Historial de Pagos' aquí.
                          ],
                        ),
                      ),

                      // Menú General
                      Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: Styles.spacingMedium,
                          vertical: Styles.spacingMedium,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildMenuItem(
                              icon: Icons.person_outline,
                              iconColor: const Color(0xFF6B7280),
                              iconBgColor: const Color(0xFFF3F4F6),
                              title: 'Editar perfil',
                              subtitle: 'Actualiza tu información personal',
                              onTap: () => context.push(
                                '/edit-profile',
                                extra: userData,
                              ),
                            ),
                            _buildDivider(),
                            _buildMenuItem(
                              icon: Icons.workspace_premium,
                              iconColor: const Color(0xFFFFB800),
                              iconBgColor: const Color(0xFFFFF7E6),
                              title: 'Suscripción Premium',
                              subtitle: 'Desbloquea funciones exclusivas',
                              onTap: () =>
                                  setState(() => showPremiumModal = true),
                            ),
                            _buildDivider(),
                            _buildMenuItem(
                              icon: Icons.settings_outlined,
                              iconColor: const Color(0xFF6B7280),
                              iconBgColor: const Color(0xFFF3F4F6),
                              title: 'Configuración',
                              subtitle: 'Preferencias y notificaciones',
                              onTap: () {},
                            ),
                          ],
                        ),
                      ),

                      // Botón Cerrar sesión
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

  // --- WIDGETS AUXILIARES ---
  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(Styles.spacingMedium),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              SizedBox(width: Styles.spacingMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyles.body.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Styles.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyles.caption.copyWith(
                        fontSize: 13,
                        color: Styles.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Styles.textSecondary, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey[200],
      indent: Styles.spacingMedium,
      endIndent: Styles.spacingMedium,
    );
  }

  Widget _buildPremiumModal() {
    return GestureDetector(
      onTap: () => setState(() => showPremiumModal = false),
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: EdgeInsets.all(Styles.spacingLarge),
              padding: EdgeInsets.all(Styles.spacingLarge),
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
                        onPressed: () =>
                            setState(() => showPremiumModal = false),
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
              if (context.mounted) Navigator.pop(context);
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
}
