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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cambiando a modo $newRole. Redirigiendo...'),
            backgroundColor: Styles.successColor,
            duration: const Duration(seconds: 1),
          ),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    if (_userRole != AuthService.ROLE_PENDING && _userRole != 'indefinido') {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Styles.primaryColor),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenHeight = constraints.maxHeight;
            // Calculamos alturas dinámicas para que todo quepa mejor
            final imageHeight =
                screenHeight * 0.35; // 35% de la altura disponible

            return FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: Styles.spacingLarge,
                    vertical: Styles.spacingMedium,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: screenHeight - (Styles.spacingMedium * 2),
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Logo
                          Center(
                            child: Image.asset(
                              'assets/images/logoColor.png',
                              height:
                                  40, // Un poco más pequeño para dar espacio
                              fit: BoxFit.contain,
                            ),
                          ),

                          SizedBox(height: Styles.spacingLarge),

                          // Título principal
                          Text(
                            '¿Con qué quieres empezar?',
                            style: TextStyles.title.copyWith(
                              fontSize: 26, // Ligeramente ajustado
                              fontWeight: FontWeight.bold,
                              color: Styles.textPrimary,
                              letterSpacing: -0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          SizedBox(height: Styles.spacingSmall),

                          // Descripción
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: Styles.spacingSmall,
                            ),
                            child: Text(
                              'Puedes explorar inmuebles o freelancers cerca de ti, o publicar tu propio inmueble o servicio para que otros te encuentren fácilmente.',
                              style: TextStyles.body.copyWith(
                                color: Styles.textSecondary,
                                fontSize:
                                    14, // Ajustado para mejor lectura en bloque
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                          // Espacio flexible superior
                          const Spacer(),

                          // Imagen ilustrativa (Responsive)
                          Center(
                            child: Image.asset(
                              'assets/images/conQueQuieresEmpesar.png',
                              height: imageHeight.clamp(
                                200.0,
                                350.0,
                              ), // Mínimo 200, Máximo 350
                              fit: BoxFit.contain,
                            ),
                          ),

                          // Espacio flexible inferior
                          const Spacer(),

                          // Botones horizontales mejorados
                          Row(
                            children: [
                              // Botón Inmobiliaria
                              Expanded(
                                child: _buildRoleButton(
                                  title: 'Inmobiliaria',
                                  icon: Icons.home_work_rounded,
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Styles.primaryColor,
                                      Color(0xFFFF8C42),
                                    ],
                                  ),
                                  onTap: () =>
                                      _updateRoleAndNavigate('inmobiliaria'),
                                  isLoading:
                                      _isLoading && _userRole == 'inmobiliaria',
                                ),
                              ),

                              SizedBox(width: Styles.spacingMedium),

                              // Botón Trabajo
                              Expanded(
                                child: _buildRoleButton(
                                  title: 'Trabajo',
                                  icon: Icons.work_rounded,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Styles.textPrimary,
                                      Colors.grey[800]!,
                                    ],
                                  ),
                                  onTap: () =>
                                      _updateRoleAndNavigate('trabajo'),
                                  isLoading:
                                      _isLoading && _userRole == 'trabajo',
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: Styles.spacingLarge),

                          // Footer info
                          Center(
                            child: Text(
                              'Podrás cambiar de módulo en cualquier momento',
                              style: TextStyles.caption.copyWith(
                                color: Styles.textSecondary,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRoleButton({
    required String title,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
    required bool isLoading,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 110,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: gradient.colors.first.withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 32),
                ),
              SizedBox(height: Styles.spacingMedium),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
