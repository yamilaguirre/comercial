import 'package:flutter_modular/flutter_modular.dart';
import 'package:my_first_app/providers/auth_provider.dart';

/// Un Guard que se usa en la ruta principal ('/') del AuthModule.
/// Su propósito es redirigir a los usuarios ya autenticados a la
/// pantalla de selección de rol ('/select-role'), saltándose el Onboarding.
class OnboardingGuard extends RouteGuard {
  OnboardingGuard() : super();

  @override
  Future<bool> canActivate(String path, ModularRoute route) async {
    // Obtenemos el servicio de autenticación
    final authService = Modular.get<AuthService>();

    // Si el usuario ya está autenticado (logueado)
    if (authService.isAuthenticated) {
      // Redirigir a select-role
      Modular.to.navigate('/select-role');
      return false;
    }

    // Si no está autenticado, permitimos la navegación a la ruta actual (OnboardingScreen).
    return true;
  }
}
