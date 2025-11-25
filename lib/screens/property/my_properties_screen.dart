import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class MyPropertiesScreen extends StatelessWidget {
  const MyPropertiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Publicaciones'),
        backgroundColor: Colors.brown,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'RUTA SECUNDARIA: Mis Publicaciones',
              style: TextStyle(fontSize: 20, color: Colors.brown),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Modular.to.pop(),
              child: const Text('Volver'),
            ),
          ],
        ),
      ),
    );
  }
}
