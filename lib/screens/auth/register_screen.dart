import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import '../../theme/theme.dart';

// Esta pantalla ahora solo es el punto de entrada para el registro/login
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Styles.textPrimary),
          onPressed: () => Modular.to.navigate('/login'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(Styles.spacingLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Image.asset(
                  'assets/images/logoColor.png',
                  height: 60,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(height: Styles.spacingXLarge),

              Text(
                '¡Bienvenido a MobiliariaAPP!',
                style: TextStyles.title.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Styles.primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: Styles.spacingSmall),
              Text(
                'Regístrate para encontrar o publicar propiedades y servicios.',
                style: TextStyles.body.copyWith(color: Styles.textSecondary),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: Styles.spacingXLarge),

              // Botón Único para ir al formulario de registro (Cliente por defecto)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => Modular.to.pushNamed(
                    '/register-form',
                    arguments: 'cliente',
                  ), // El formulario maneja el registro real
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Crear una cuenta nueva'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Styles.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              SizedBox(height: Styles.spacingXLarge * 2),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '¿Ya tienes una cuenta? ',
                    style: TextStyles.body.copyWith(
                      color: Styles.textSecondary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Modular.to.navigate('/login'),
                    child: Text(
                      'Inicia sesión',
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
}
