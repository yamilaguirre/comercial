import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:my_first_app/screens/onboarding/onboarding_screen.dart';
import 'package:my_first_app/screens/auth/login_screen.dart';
import 'package:my_first_app/screens/auth/register_screen.dart';
import 'package:my_first_app/screens/auth/register_form_screen.dart';
import 'package:my_first_app/screens/auth/role_selection_screen.dart';
import 'package:my_first_app/screens/auth/inmobiliaria_register_screen.dart';
import 'package:my_first_app/screens/auth/inmobiliaria_login_screen.dart';
import 'package:my_first_app/screens/auth/auth_loading_screen.dart';
import 'package:my_first_app/screens/inmobiliaria/inmobiliaria_dashboard_screen.dart';
import 'package:my_first_app/core/guards/auth_guard.dart';

class AuthModule extends Module {
  @override
  void binds(i) {}

  @override
  void routes(r) {
    // 1. Ruta Inicial: Pantalla de carga que verifica auth y redirige
    r.child(
      '/',
      child: (context) => const AuthLoadingScreen(),
    );

    // 2. Onboarding (sin guard)
    r.child('/onboarding', child: (context) => const OnboardingScreen());

    // 3. Otras Rutas
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
    );

    // 4. Rutas de Inmobiliaria
    r.child('/inmobiliaria-register', child: (context) => const InmobiliariaRegisterScreen());
    r.child('/inmobiliaria-login', child: (context) => const InmobiliariaLoginScreen());
    r.child('/inmobiliaria-dashboard', child: (context) => const InmobiliariaDashboardScreen());
  }
}
