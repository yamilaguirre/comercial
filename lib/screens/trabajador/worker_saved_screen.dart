import 'package:flutter/material.dart';

class WorkerSavedScreen extends StatelessWidget {
  const WorkerSavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trabajos Guardados'),
        backgroundColor: Colors.yellow.shade700,
      ),
      body: const Center(
        child: Text(
          'SIDEBAR: Favoritos de Trabajos',
          style: TextStyle(fontSize: 20, color: Colors.amber),
        ),
      ),
    );
  }
}
