import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PropertyListScreen extends StatelessWidget {
  const PropertyListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explorar Propiedades'),
        backgroundColor: Colors.blue.shade700,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'HOME: Lista de Propiedades',
              style: TextStyle(fontSize: 24, color: Colors.blue),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Modular.to.navigate('/property/new'),
              child: const Text('Ir a Publicar Nueva'),
            ),
            ElevatedButton(
              onPressed: () => Modular.to.navigate('/property/detail/123'),
              child: const Text('Ver Detalle (sin Sidebar)'),
            ),
          ],
        ),
      ),
    );
  }
}
