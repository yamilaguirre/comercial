import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:chaski_comercial/screens/onboarding/onboarding_screen.dart';
import 'package:chaski_comercial/screens/auth/login_screen.dart';
import 'package:chaski_comercial/screens/auth/login_screen_phone.dart';
import 'package:chaski_comercial/screens/auth/register_screen.dart';
import 'package:chaski_comercial/screens/auth/register_form_screen.dart';
import 'package:chaski_comercial/screens/auth/role_selection_screen.dart';
import 'package:chaski_comercial/screens/auth/real_estate_registration_wizard.dart';
import 'package:chaski_comercial/screens/auth/inmobiliaria_login_screen.dart';
import 'package:chaski_comercial/screens/inmobiliaria/inmobiliaria_dashboard_screen.dart';
import 'package:chaski_comercial/core/guards/auth_guard.dart';
import 'package:chaski_comercial/core/guards/onboarding_guard.dart';

class AuthModule extends Module {
  @override
  void binds(i) {}

  @override
  void routes(r) {
    // 1. Ruta Inicial: Onboarding
    r.child(
      '/',
      child: (context) => const OnboardingScreen(),
      guards: [OnboardingGuard()],
    );

    // 2. Otras Rutas
    r.child('/login', child: (context) => const LoginScreen());
    r.child('/login-phone', child: (context) => const LoginScreenPhone());
    r.child('/register', child: (context) => const RegisterScreen());
    r.child(
      '/register-form',
      child: (context) =>
          RegisterFormScreen(userType: r.args.data as String? ?? 'cliente'),
    );

    // 3. Selección de Rol
    r.child('/select-role', child: (context) => const RoleSelectionScreen());

    // 4. Rutas de Inmobiliaria
    r.child(
      '/inmobiliaria-register',
      child: (context) => const RealEstateRegistrationWizard(),
    );
    r.child(
      '/inmobiliaria-login',
      child: (context) => const InmobiliariaLoginScreen(),
    );
    r.child(
      '/inmobiliaria-dashboard',
      child: (context) => const InmobiliariaDashboardScreen(),
    );
  }
}
