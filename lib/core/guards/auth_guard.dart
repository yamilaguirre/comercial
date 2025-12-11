import 'package:flutter_modular/flutter_modular.dart';
import 'package:chaski_comercial/providers/auth_provider.dart';

class AuthGuard extends RouteGuard {
  final String requiredRole;

  AuthGuard({this.requiredRole = 'all'}) : super(redirectTo: '/login');

  @override
  Future<bool> canActivate(String path, ModularRoute route) async {
    final authService = Modular.get<AuthService>();

    if (!authService.isAuthenticated) {
      return false;
    }

    // Permitir acceso a select-role para usuarios autenticados
    if (path == '/select-role') {
      return true;
    }

    if (requiredRole != 'all') {
      final userRole = authService.userRole;
      
      // Verificar suscripción para inmobiliaria_empresa
      if (userRole == 'inmobiliaria_empresa') {
        final hasPremium = authService.isPremium;
        
        if (!hasPremium && !path.contains('onboarding') && !path.contains('subscription')) {
          Modular.to.navigate('/inmobiliaria/onboarding');
          return false;
        }
      }
      
      // Permitir 'inmobiliaria_empresa' cuando se requiere 'inmobiliaria'
      if (requiredRole == 'inmobiliaria' && 
          (userRole == 'inmobiliaria' || userRole == 'inmobiliaria_empresa')) {
        return true;
      }
      
      if (userRole != requiredRole) {
        final target = userRole == 'trabajo'
            ? '/worker/home'
            : '/property/home';
        Modular.to.navigate(target);
        return false;
      }
    }

    return true;
  }
}
