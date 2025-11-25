import 'package:flutter/material.dart';

class WorkerMessagesScreen extends StatelessWidget {
  const WorkerMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buzón de Trabajo'),
        backgroundColor: Colors.pink.shade300,
      ),
      body: const Center(
        child: Text(
          'SIDEBAR: Mensajes (Chat) de Trabajadores',
          style: TextStyle(fontSize: 20, color: Colors.pink),
        ),
      ),
    );
  }
}
