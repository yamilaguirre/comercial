import 'package:flutter_modular/flutter_modular.dart';
import 'package:chaski_comercial/providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Un Guard que se usa en la ruta principal ('/') del AuthModule.
/// Redirige según el rol del usuario autenticado.
class OnboardingGuard extends RouteGuard {
  OnboardingGuard() : super();

  @override
  Future<bool> canActivate(String path, ModularRoute route) async {
    final authService = Modular.get<AuthService>();

    // Si el usuario está autenticado
    if (authService.isAuthenticated) {
      final user = authService.currentUser;
      if (user != null) {
        // Leer datos del usuario de Firestore
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        final role = doc.data()?['role'];

        // Si es empresa inmobiliaria, verificar suscripción
        if (role == 'inmobiliaria_empresa') {
          // Verificar si tiene suscripción premium activa
          final subscriptionStatus =
              doc.data()?['subscriptionStatus'] as Map<String, dynamic>?;
          final hasPremium =
              subscriptionStatus != null &&
              subscriptionStatus['status'] == 'active';

          if (hasPremium) {
            // Tiene premium → ir a dashboard
            Modular.to.navigate('/inmobiliaria/home');
          } else {
            // NO tiene premium → ir a onboarding de inmobiliaria
            Modular.to.navigate('/inmobiliaria/onboarding');
          }
        } else {
          // Usuario normal: ir directo a property list
          Modular.to.navigate('/property/home');
        }
      }
      return false;
    }

    // Si no está autenticado, mostrar onboarding
    return true;
  }
}
