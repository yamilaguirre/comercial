// filepath: lib/screens/auth/role_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import '../../theme/theme.dart';
import '../../providers/auth_provider.dart';

/// Pantalla que permite al usuario seleccionar su rol principal
/// ('inmobiliaria' o 'trabajo') después de un registro/login exitoso.
/// Llama a authService.updateUserRole para modificar el campo 'role'/'status'
/// en Firestore y navega a la ruta base del módulo correspondiente.
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  // Obtenemos la instancia del AuthService inyectada por Modular
  final AuthService _authService = Modular.get<AuthService>();

  // Escucha el estado de carga
  bool get _isLoading => _authService.isLoading;
  // Obtenemos el rol actual (será 'indefinido' gracias al AuthService)
  String get _userRole => _authService.userRole;

  @override
  void initState() {
    super.initState();
    _authService.addListener(_onAuthServiceChanged);
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthServiceChanged);
    super.dispose();
  }

  void _onAuthServiceChanged() {
    if (mounted) {
      // Reconstruye el widget para actualizar el estado del botón
      setState(() {});

      // Lógica de redirección: si el rol es válido (no es 'indefinido'), navegamos.
      if (_userRole != AuthService.ROLE_PENDING) {
        _navigateBasedOnRole(_userRole);
      }
    }
  }

  void _navigateBasedOnRole(String role) {
    // Las rutas de los módulos en AppModule son /property y /worker
    final targetRoute = role == 'trabajo' ? '/worker/' : '/property/';

    // Usamos navigate para reemplazar el historial y redirigir a la raíz del módulo
    Modular.to.navigate(targetRoute);
  }

  // Función para actualizar el rol en Firestore y redirigir
  void _updateRoleAndNavigate(String newRole) async {
    final user = _authService.currentUser;

    if (user == null) {
      Modular.to.navigate('/login');
      return;
    }

    try {
      // CLAVE: Actualizar 'role' y 'status' en Firebase
      await _authService.updateUserRole(newRole);

      // Notificación de éxito
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cambiando a modo $newRole. Redirigiendo...'),
            backgroundColor: Styles.successColor,
            duration: const Duration(seconds: 1),
          ),
        );
      }

      // La navegación se dispara automáticamente en _onAuthServiceChanged
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al guardar el rol y estado: ${_authService.errorMessage ?? e}',
            ),
            backgroundColor: Styles.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si el rol es distinto de 'indefinido', significa que está esperando redirección
    if (_userRole != AuthService.ROLE_PENDING) {
      // Muestra un loader mientras ocurre la redirección.
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Styles.primaryColor),
        ),
      );
    }

    final bool isWorkerSelected = _userRole == 'trabajo';
    final bool isInmobiliariaSelected = _userRole == 'inmobiliaria';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(Styles.spacingLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Image.asset(
                  'assets/images/logoColor.png',
                  height: 60,
                  fit: BoxFit.contain,
                ),
              ),

              SizedBox(height: Styles.spacingXLarge),

              Text(
                '¿Con qué quieres empezar?',
                style: TextStyles.title.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Styles.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: Styles.spacingMedium),

              Text(
                'Puedes explorar inmuebles o freelancers cerca de ti, o publicar tu propio inmueble o servicio para que otros te encuentren fácilmente.',
                style: TextStyles.body.copyWith(color: Styles.textSecondary),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: Styles.spacingXLarge),

              Center(
                child: Image.asset(
                  'assets/images/conQueQuieresEmpesar.png',
                  height: 250,
                  fit: BoxFit.contain,
                ),
              ),

              const Spacer(),

              // Botones de Selección
              Row(
                children: [
                  // Botón 1: Inmobiliaria
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () => _updateRoleAndNavigate('inmobiliaria'),
                        icon: const Icon(Icons.home_work, size: 24),
                        label: _isLoading && isInmobiliariaSelected
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text('Inmobiliaria'),
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
                  ),
                  SizedBox(width: Styles.spacingMedium),

                  // Botón 2: Trabajo
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () => _updateRoleAndNavigate('trabajo'),
                        icon: const Icon(Icons.work_outline, size: 24),
                        label: _isLoading && isWorkerSelected
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text('Trabajo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Styles.textPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: Styles.spacingMedium),
            ],
          ),
        ),
      ),
    );
  }
}
