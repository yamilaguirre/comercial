// screens/auth_wrapper.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'onboarding/onboarding_screen.dart';
import '../core/layouts/main_layout.dart';
import 'property_list_screen.dart';

class AuthWrapper extends StatelessWidget {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          // Usuario logueado - mostrar app principal con tabs
          return MainLayout(
            child: PropertyListScreen(),
          );
        } else {
          // Usuario no logueado - mostrar onboarding
          return const OnboardingScreen();
        }
      },
    );
  }
}