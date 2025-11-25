import 'package:flutter/material.dart';

class PropertyMessagesScreen extends StatelessWidget {
  const PropertyMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buzón Inmobiliaria'),
        backgroundColor: Colors.teal,
      ),
      body: const Center(
        child: Text(
          'SIDEBAR: Mensajes (Chat) de Propiedades',
          style: TextStyle(fontSize: 20, color: Colors.teal),
        ),
      ),
    );
  }
}
