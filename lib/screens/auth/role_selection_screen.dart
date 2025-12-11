// filepath: lib/screens/auth/role_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import '../../theme/theme.dart';
import '../../providers/auth_provider.dart';

/// Pantalla que permite al usuario seleccionar su rol principal
/// ('inmobiliaria' o 'trabajo') después de un registro/login exitoso.
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = Modular.get<AuthService>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool get _isLoading => _authService.isLoading;
  String get _userRole => _authService.userRole;

  @override
  void initState() {
    super.initState();
    _authService.addListener(_onAuthServiceChanged);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthServiceChanged);
    _animationController.dispose();
    super.dispose();
  }

  void _onAuthServiceChanged() {
    if (mounted) {
      setState(() {});
      if (_userRole != AuthService.ROLE_PENDING) {
        _navigateBasedOnRole(_userRole);
      }
    }
  }

  void _navigateBasedOnRole(String role) {
    final targetRoute = role == 'trabajo'
        ? '/worker/home-worker'
        : '/property/home';
    Modular.to.navigate(targetRoute);
  }

  void _updateRoleAndNavigate(String newRole) async {
    final user = _authService.currentUser;
    if (user == null) {
      Modular.to.navigate('/login');
      return;
    }

    try {
      await _authService.updateUserRole(newRole);
      if (mounted) {}
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al guardar el rol: ${_authService.errorMessage ?? e}',
            ),
            backgroundColor: Styles.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    await _authService.signOut();
    if (mounted) {
      Modular.to.navigate('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          await _handleLogout();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Fondo full-screen; no necesitamos tamaños intermedios

            return Stack(
              fit: StackFit.expand,
              children: [
                // Fondo: imagen a pantalla completa
                Image.asset(
                  'assets/images/onboardin4.png',
                  fit: BoxFit.cover,
                ),
                // Overlay: degradé azul similar al onboarding
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x3FBFBFBF),
                        Color(0x9F1B54C8),
                        Color(0xFF001BB7),
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
                // Contenido: logo arriba, titulo/descripcion al medio, botones abajo - RESPONSIVE
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        // Logo arriba
                        SafeArea(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: Styles.spacingLarge,
                              vertical: Styles.spacingMedium,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/images/logo.png',
                                  height: 44,
                                  fit: BoxFit.contain,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Espaciador flexible para empujar todo el contenido al fondo
                        const Spacer(),

                        // Todo el contenido pegado al fondo (título, descripción, botones de rol y botón siguiente)
                        SafeArea(
                          child: Padding(
                            padding: EdgeInsets.all(Styles.spacingLarge),
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Título
                                  Text(
                                    '¿Con qué quieres empezar?',
                                    style: TextStyles.title.copyWith(
                                      fontSize: 24,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: Styles.spacingMedium),
                                  
                                  // Descripción
                                  Text(
                                    'Puedes explorar inmuebles o trabajadores cerca de ti, o publicar tu propio inmueble o servicio para que otros te encuentren fácilmente.',
                                    style: TextStyles.body.copyWith(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.9),
                                      height: 1.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),

                                  SizedBox(height: Styles.spacingLarge),

                                  // Botones de rol - responsive
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildSolidButton(
                                          title: 'Inmobiliaria',
                                          icon: Icons.home_rounded,
                                          onTap: () =>
                                              _updateRoleAndNavigate('inmobiliaria'),
                                          backgroundColor: Colors.white,
                                          foregroundColor: Styles.primaryColor,
                                        ),
                                      ),
                                      SizedBox(width: Styles.spacingMedium),
                                      Expanded(
                                        child: _buildSolidButton(
                                          title: 'Trabajo',
                                          icon: Icons.work_rounded,
                                          onTap: () =>
                                              _updateRoleAndNavigate('trabajo'),
                                          backgroundColor: const Color(0xFF0B0B0E),
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      ),
    );
  }

  // Eliminamos el antiguo botón con gradiente porque el nuevo diseño usa
  // botones sólidos. Si se necesita, se puede recuperar desde historial.

  Widget _buildSolidButton({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(Styles.radiusMedium),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(Styles.radiusMedium),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: foregroundColor,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    style: TextStyles.button.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: foregroundColor,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
