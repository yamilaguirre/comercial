import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/theme.dart';

class WorkListScreen extends StatelessWidget {
  const WorkListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Servicios y Trabajadores',
          style: TextStyles.subtitle.copyWith(
            color: Styles.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.handyman_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 20),
            Text(
              'Aquí se mostrarán los servicios de construcción y mantenimiento.',
              style: TextStyles.body.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              'Rol actual: Trabajador',
              style: TextStyles.caption.copyWith(
                color: Styles.infoColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => context.push(
                '/work/new',
              ), // Ruta futura para publicar un servicio
              icon: const Icon(Icons.add_task),
              label: const Text('Publicar mi Servicio'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Styles.infoColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
