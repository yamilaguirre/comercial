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

    // Esperar a que el auth esté listo
    if (!authService.isAuthReady) {
      // Esperar hasta 3 segundos a que se cargue el estado de auth
      int attempts = 0;
      while (!authService.isAuthReady && attempts < 30) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
    }

    // Si el usuario ya está autenticado (logueado)
    if (authService.isAuthenticated) {
      // Esperar a que el rol esté cargado
      int roleAttempts = 0;
      while (authService.userRole == 'indefinido' && roleAttempts < 20) {
        await Future.delayed(const Duration(milliseconds: 100));
        roleAttempts++;
      }

      // Verificar si es inmobiliaria y redirigir a su dashboard
      if (authService.userRole == 'inmobiliaria_empresa') {
        Modular.to.navigate('/inmobiliaria/home');
      } else {
        // Para otros usuarios, ir a select-role
        Modular.to.navigate('/select-role');
      }

      // Retornamos false para bloquear la navegación actual (OnboardingScreen)
      return false;
    }

    // Si no está autenticado, permitimos la navegación a la ruta actual (OnboardingScreen).
    return true;
  }
}
