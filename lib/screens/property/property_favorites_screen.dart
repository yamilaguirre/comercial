import 'package:flutter/material.dart';

class PropertyFavoritesScreen extends StatelessWidget {
  const PropertyFavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guardados Inmobiliaria'),
        backgroundColor: Colors.lightBlue,
      ),
      body: const Center(
        child: Text(
          'SIDEBAR: Favoritos de Propiedades',
          style: TextStyle(fontSize: 20, color: Colors.blueGrey),
        ),
      ),
    );
  }
}
