import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PropertyDetailScreen extends StatelessWidget {
  final String propertyId;
  final dynamic propertyData;

  const PropertyDetailScreen({
    super.key,
    required this.propertyId,
    this.propertyData,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detalle Propiedad $propertyId'),
        backgroundColor: Colors.indigo,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'RUTA SECUNDARIA: Detalle de Propiedad $propertyId',
              style: const TextStyle(fontSize: 20, color: Colors.indigo),
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
