import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import '../../providers/auth_provider.dart';
import '../../theme/theme.dart';

class AuthLoadingScreen extends StatefulWidget {
  const AuthLoadingScreen({super.key});

  @override
  State<AuthLoadingScreen> createState() => _AuthLoadingScreenState();
}

class _AuthLoadingScreenState extends State<AuthLoadingScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndRedirect();
  }

  Future<void> _checkAuthAndRedirect() async {
    final authService = Modular.get<AuthService>();

    // Esperar a que el auth esté listo
    while (!authService.isAuthReady) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (!mounted) return;

    // Si está autenticado, esperar a que el rol esté cargado
    if (authService.isAuthenticated) {
      // Esperar hasta que el rol no sea 'indefinido' o timeout de 2 segundos
      int attempts = 0;
      while (authService.userRole == 'indefinido' && attempts < 20) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }

      if (!mounted) return;

      // Redirigir según el rol
      if (authService.userRole == 'inmobiliaria_empresa') {
        Modular.to.navigate('/inmobiliaria/home');
      } else if (authService.userRole == 'indefinido') {
        Modular.to.navigate('/select-role');
      } else {
        // Otros roles van a select-role
        Modular.to.navigate('/select-role');
      }
    } else {
      // No autenticado, ir a onboarding
      Modular.to.navigate('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.home_work,
              size: 80,
              color: Styles.primaryColor,
            ),
            SizedBox(height: Styles.spacingLarge),
            const CircularProgressIndicator(
              color: Styles.primaryColor,
            ),
            SizedBox(height: Styles.spacingLarge),
            Text(
              'Cargando...',
              style: TextStyles.body.copyWith(
                color: Styles.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
