import 'package:flutter/material.dart';

class HomeWorkScreen extends StatelessWidget {
  const HomeWorkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio de Trabajo'),
        backgroundColor: Colors.green.shade700,
      ),
      body: const Center(
        child: Text(
          'HOME: Lista de Trabajos y Servicios (Worker)',
          style: TextStyle(fontSize: 24, color: Colors.green),
        ),
      ),
    );
  }
}
