import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

/// Diálogo simple que muestra cuando una funcionalidad requiere suscripción premium
class PremiumFeatureLockDialog extends StatelessWidget {
  /// Descripción de la funcionalidad que se quiere desbloquear
  /// Ejemplo: "publicar propiedades destacadas", "ver estadísticas avanzadas"
  final String featureName;

  const PremiumFeatureLockDialog({super.key, required this.featureName});

  /// Método estático para mostrar el diálogo fácilmente
  static Future<void> show(BuildContext context, String featureName) {
    return showDialog(
      context: context,
      builder: (context) => PremiumFeatureLockDialog(featureName: featureName),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icono de candado premium
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF8C00), Color(0xFFFF0080)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 20),

            // Título
            const Text(
              'SUSCRÍBETE AL PLAN PREMIUM',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 12),

            // Mensaje con la funcionalidad bloqueada
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF7F8C8D),
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: 'para '),
                  TextSpan(
                    text: featureName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF5500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Botón para ir a suscripción
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Modular.to.pushNamed('/property/subscription-payment');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5500),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.workspace_premium, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Ver Planes Premium',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Botón para cerrar
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Ahora no',
                style: TextStyle(color: Color(0xFF95A5A6), fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
