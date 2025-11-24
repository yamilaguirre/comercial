import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/theme.dart';
import '../../providers/auth_provider.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  // Función para actualizar el rol en Firestore y redirigir
  void _updateRoleAndNavigate(BuildContext context, String newRole) async {
    // Usamos read para acceder al provider sin escuchar
    final authService = context.read<AuthService>();
    final user = authService.currentUser;

    if (user == null) {
      context.go('/login');
      return;
    }

    try {
      // 1. Actualizar 'role' y 'status' en Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {
          'role': newRole,
          'status': newRole, // Se establece el status igual al rol
        },
      );

      // 2. Determinar la ruta según el rol seleccionado
      final targetRoute = newRole == 'trabajo' ? '/work-home' : '/home';

      // 3. Mostrar mensaje de éxito
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rol actualizado a $newRole.'),
            backgroundColor: Styles.successColor,
            duration: const Duration(seconds: 1),
          ),
        );

        // 4. Navegar manualmente a la ruta correcta
        context.go(targetRoute);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar el rol: $e'),
            backgroundColor: Styles.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Escucha el estado de carga del servicio de autenticación
    final authService = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: Colors.white,
      // Se eliminó el AppBar para que coincida con el diseño de la imagen
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(Styles.spacingLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo superior (Simulando el logo COMERCIAL)
              Center(
                child: Image.asset(
                  'assets/images/logoColor.png',
                  height: 60,
                  fit: BoxFit.contain,
                ),
              ),

              SizedBox(height: Styles.spacingXLarge),

              // Título "¿Con qué quieres empezar?"
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

              // Subtítulo descriptivo
              Text(
                'Puedes explorar inmuebles o freelancers cerca de ti, o publicar tu propio inmueble o servicio para que otros te encuentren fácilmente.',
                style: TextStyles.body.copyWith(color: Styles.textSecondary),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: Styles.spacingXLarge),

              // Imagen central conQueQuieresEmpesar.png
              Center(
                child: Image.asset(
                  'assets/images/conQueQuieresEmpesar.png',
                  height: 250, // Ajuste de altura para que se vea bien
                  fit: BoxFit.contain,
                ),
              ),

              const Spacer(), // Empuja los botones hacia abajo
              // Contenedor de botones en la parte inferior
              Row(
                children: [
                  // Botón 1: Inmobiliaria (Principal Color)
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: authService.isLoading
                            ? null
                            : () => _updateRoleAndNavigate(
                                context,
                                'inmobiliaria',
                              ),
                        icon: const Icon(Icons.home_work, size: 24),
                        label: const Text('Inmobiliaria'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Styles.primaryColor, // Azul fuerte
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

                  // Botón 2: Trabajo (Fondo Oscuro)
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: authService.isLoading
                            ? null
                            : () => _updateRoleAndNavigate(context, 'trabajo'),
                        icon: const Icon(Icons.work_outline, size: 24),
                        label: const Text('Trabajo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Styles.textPrimary, // Negro/Oscuro
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
