import 'package:flutter/material.dart';

class PropertyAlertsScreen extends StatelessWidget {
  const PropertyAlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avisos Inmobiliaria'),
        backgroundColor: Colors.purple,
      ),
      body: const Center(
        child: Text(
          'SIDEBAR: Avisos/Notificaciones de Propiedades',
          style: TextStyle(fontSize: 20, color: Colors.purple),
        ),
      ),
    );
  }
}
