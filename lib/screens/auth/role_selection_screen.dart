import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/theme.dart';
import '../../providers/auth_provider.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  // Función para actualizar el rol en Firestore y redirigir explícitamente
  void _updateRoleAndNavigate(BuildContext context, String newRole) async {
    final authService = context.read<AuthService>();
    final user = authService.currentUser;

    if (user == null) {
      context.go('/login');
      return;
    }

    try {
      // 1. Actualizar 'role' y 'status' en Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'role': newRole, 'status': newRole},
      );

      // 2. Notificar listeners (opcional en este punto, pero buena práctica)
      await user.reload();
      authService.notifyListeners();

      // 3. REDIRECCIÓN EXPLÍCITA
      if (context.mounted) {
        if (newRole == 'inmobiliaria') {
          context.go('/property-home'); // Redirige a PropertyListScreen
        } else {
          context.go('/work-home'); // Redirige a WorkListScreen
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar el rol y estado: $e'),
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
                  // Botón 1: Inmobiliaria -> /property-home
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

                  // Botón 2: Trabajo -> /work-home
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
