import 'package:flutter/material.dart';

class WorkerAlertsScreen extends StatelessWidget {
  const WorkerAlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avisos de Trabajo'),
        backgroundColor: Colors.grey.shade700,
      ),
      body: const Center(
        child: Text(
          'SIDEBAR: Avisos/Notificaciones de Trabajadores',
          style: TextStyle(fontSize: 20, color: Colors.grey),
        ),
      ),
    );
  }
}
