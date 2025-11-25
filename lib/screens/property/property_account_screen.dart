import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:my_first_app/providers/auth_provider.dart';

class PropertyAccountScreen extends StatelessWidget {
  const PropertyAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Modular.get<AuthService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Cuenta Inmobiliaria'),
        backgroundColor: Colors.orange,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'SIDEBAR: Perfil de Inmobiliaria',
              style: TextStyle(fontSize: 20, color: Colors.orange),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => authService.signOut(),
              child: const Text('Cerrar Sesión'),
            ),
            ElevatedButton(
              onPressed: () => Modular.to.navigate('/auth/select-role'),
              child: const Text('Cambiar de Rol'),
            ),
          ],
        ),
      ),
    );
  }
}
