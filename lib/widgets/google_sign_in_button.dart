import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import '../providers/auth_provider.dart';

class GoogleSignInButton extends StatelessWidget {
  final AuthService _authService = Modular.get<AuthService>();

  GoogleSignInButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () async {
        final user = await _authService.signInWithGoogle();
        if (user != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Bienvenido ${user.displayName}')),
          );
        }
      },
      icon: const Icon(Icons.login),
      label: const Text('Iniciar sesión con Google'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }
}
