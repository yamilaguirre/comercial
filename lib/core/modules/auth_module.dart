import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:my_first_app/screens/onboarding/onboarding_screen.dart';
import 'package:my_first_app/screens/auth/login_screen.dart';
import 'package:my_first_app/screens/auth/register_screen.dart';
import 'package:my_first_app/screens/auth/register_form_screen.dart';
import 'package:my_first_app/screens/auth/role_selection_screen.dart';
import 'package:my_first_app/core/guards/auth_guard.dart';
import 'package:my_first_app/core/guards/onboarding_guard.dart'; // <-- Nueva importación

class AuthModule extends Module {
  @override
  void binds(i) {}

  @override
  void routes(r) {
    // 1. Ruta Inicial: Onboarding
    // Aplicamos OnboardingGuard para redirigir a '/select-role' si el usuario está logueado.
    r.child(
      '/',
      child: (context) => const OnboardingScreen(),
      guards: [OnboardingGuard()], // <-- Nuevo Guard
    );

    // 2. Otras Rutas
    r.child('/login', child: (context) => const LoginScreen());
    r.child('/register', child: (context) => const RegisterScreen());
    r.child(
      '/register-form',
      child: (context) =>
          RegisterFormScreen(userType: r.args.data as String? ?? 'cliente'),
    );

    // 3. Selección de Rol
    r.child(
      '/select-role',
      child: (context) => const RoleSelectionScreen(),
      // Mantenemos AuthGuard aquí para asegurar que solo usuarios autenticados
      // puedan acceder a la selección de rol directamente.
      guards: [AuthGuard(requiredRole: 'all')],
    );
  }
}
