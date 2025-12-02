import 'package:flutter_modular/flutter_modular.dart';
import 'package:my_first_app/providers/auth_provider.dart';
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
        // Leer SOLO el campo role de Firestore
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        final role = doc.data()?['role'];
        
        // Si es empresa inmobiliaria, ir a dashboard
        if (role == 'inmobiliaria_empresa') {
          Modular.to.navigate('/inmobiliaria/home');
        } else {
          // Cualquier otro caso, ir a role selection
          Modular.to.navigate('/select-role');
        }
      }
      return false;
    }

    // Si no está autenticado, mostrar onboarding
    return true;
  }
}
