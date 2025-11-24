import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../theme/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _handleLogin() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = await authService.signInWithEmailPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (user != null && mounted) {
        // El router automáticamente redirigirá a /home debido al redirect guard
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: Styles.spacingLarge,
            vertical: Styles.spacingXLarge,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: Styles.spacingXLarge),
              Center(
                child: Image.asset(
                  'assets/images/logoColor.png',
                  height: 60,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(height: Styles.spacingXLarge * 1.5),
              Text(
                'Inicie sesión en su cuenta',
                style: TextStyles.title.copyWith(
                  fontSize: 24,
                  color: Styles.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: Styles.spacingXLarge),
              Text(
                'Correo',
                style: TextStyles.body.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Styles.textPrimary,
                ),
              ),
              SizedBox(height: Styles.spacingSmall),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  hintText: 'ejemplo@email.com',
                  hintStyle: const TextStyle(
                    color: Color(0xFFD9D9D9),
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xFFE0E0E0),
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xFFE0E0E0),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Styles.primaryColor,
                      width: 2,
                    ),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: Styles.spacingMedium,
                    vertical: Styles.spacingMedium,
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: Styles.spacingLarge),
              Text(
                'Contraseña',
                style: TextStyles.body.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Styles.textPrimary,
                ),
              ),
              SizedBox(height: Styles.spacingSmall),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: '••••••••',
                  hintStyle: const TextStyle(
                    color: Color(0xFFD9D9D9),
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xFFE0E0E0),
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xFFE0E0E0),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Styles.primaryColor,
                      width: 2,
                    ),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: Styles.spacingMedium,
                    vertical: Styles.spacingMedium,
                  ),
                ),
              ),
              SizedBox(height: Styles.spacingXLarge),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Styles.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    disabledBackgroundColor: Styles.primaryColor.withAlpha(153),
                  ),
                  child: Text(
                    'Iniciar Sesión',
                    style: TextStyles.button.copyWith(fontSize: 16),
                  ),
                ),
              ),
              SizedBox(height: Styles.spacingLarge),
              Row(
                children: [
                  const Expanded(child: Divider(color: Color(0xFFE0E0E0))),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: Styles.spacingMedium,
                    ),
                    child: Text(
                      'o inicia sesión con',
                      style: TextStyles.caption.copyWith(
                        color: Styles.textSecondary,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: Color(0xFFE0E0E0))),
                ],
              ),
              SizedBox(height: Styles.spacingLarge),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSocialButtonWithImage(
                    'assets/images/google.png',
                    () async {
                      try {
                        final authService = Provider.of<AuthService>(
                          context,
                          listen: false,
                        );
                        final user = await authService.signInWithGoogle();
                        if (user != null && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Bienvenido ${user.displayName}'),
                            ),
                          );
                          context.go('/home');
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: ${e.toString()}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  ),
                  SizedBox(width: Styles.spacingMedium),
                  _buildSocialButtonWithImage('assets/images/facebook.png', () {
                    // TODO: Implementar login con Facebook
                  }),
                  SizedBox(width: Styles.spacingMedium),
                  _buildSocialButton(Icons.chat, const Color(0xFF1DA1F2), () {
                    // TODO: Implementar login con Twitter
                  }),
                ],
              ),
              SizedBox(height: Styles.spacingXLarge),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '¿No tienes una cuenta? ',
                    style: TextStyles.body.copyWith(
                      color: Styles.textSecondary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      context.go('/register');
                    },
                    child: Text(
                      'Regístrate',
                      style: TextStyles.body.copyWith(
                        color: Styles.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(child: Icon(icon, size: 28, color: color)),
      ),
    );
  }

  Widget _buildSocialButtonWithImage(String imagePath, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Image.asset(
            imagePath,
            width: 28,
            height: 28,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
