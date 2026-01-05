// filepath: lib/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../providers/auth_provider.dart';
import '../../theme/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // CLAVE: Se añade una clave para gestionar el estado del formulario
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // ERROR STATE: Variable para mostrar el error específico de la contraseña/credenciales
  String? _passwordError;

  // Obtenemos la instancia del AuthService inyectada por Modular
  final AuthService _authService = Modular.get<AuthService>();

  // Escucha el estado de carga y errores
  bool get _isLoading => _authService.isLoading;

  @override
  void initState() {
    super.initState();
    // Añadimos un listener para reconstruir el widget en cambios (ej. isLoading)
    _authService.addListener(_onAuthServiceChanged);
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthServiceChanged);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onAuthServiceChanged() {
    if (mounted) {
      // Reconstruye el widget para actualizar el estado (ej. botón de loading)
      setState(() {});
    }
  }

  void _handleLogin() async {
    // 1. Limpiar el error anterior
    setState(() {
      _passwordError = null;
    });

    // 2. Usar el Form Key para validar los campos
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final user = await _authService.signInWithEmailPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (user != null && mounted) {
        // Verificar que no sea empresa o agente inmobiliario
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        final role = userDoc.data()?['role'];

        // Bloquear si es empresa inmobiliaria
        if (role == 'inmobiliaria_empresa') {
          await _authService.signOut();
          setState(() {
            _passwordError =
                'Esta es una cuenta de empresa. Usa el portal inmobiliario';
          });
          return;
        }

        Future.microtask(() {
          // Redirección inmediata a /select-role
          Modular.to.navigate('/select-role');
        });
      } else if (mounted) {
        // Mensajes específicos según el error del AuthService
        final error = _authService.errorMessage ?? '';
        setState(() {
          if (error.contains('Usuario no encontrado')) {
            _passwordError = 'No existe una cuenta con este correo';
          } else if (error.contains('Contraseña incorrecta')) {
            _passwordError = 'La contraseña es incorrecta';
          } else if (error.contains('Correo inválido')) {
            _passwordError = 'El formato del correo no es válido';
          } else if (error.contains('red')) {
            _passwordError = 'Sin conexión a internet. Verifica tu red';
          } else {
            _passwordError = 'Correo o contraseña incorrectos';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _passwordError = 'No se pudo iniciar sesión. Intenta nuevamente';
        });
      }
    }
  }

  void _handleGoogleLogin() async {
    // Limpiar errores visuales al intentar con Google
    setState(() {
      _passwordError = null;
    });

    try {
      final user = await _authService.signInWithGoogle();

      if (user != null && mounted) {
        Future.microtask(() {
          Modular.to.navigate('/select-role');
        });
      } else if (mounted) {
        if (_authService.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo iniciar sesión con Google'),
              backgroundColor: Styles.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo iniciar sesión con Google'),
            backgroundColor: Styles.errorColor,
          ),
        );
      }
    }
  }

  void _goToRegister() {
    Modular.to.navigate('/register-form', arguments: 'cliente');
  }

  // --- WIDGETS DE CONSTRUCCIÓN ---

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

  // --- BUILD ---

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
          child: Form(
            // CLAVE: Usamos el Form widget
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: Styles.spacingXLarge),
                Center(
                  child: SvgPicture.asset(
                    'assets/images/Logo P2.svg',
                    height: 70,
                  ),
                ),
                SizedBox(height: Styles.spacingXLarge * 1.5),
                Text(
                  'Iniciar Sesión',
                  style: TextStyles.title.copyWith(
                    fontSize: 24,
                    color: Styles.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: Styles.spacingXLarge),

                // Tabs
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Styles.primaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Text(
                          'Con Email',
                          textAlign: TextAlign.center,
                          style: TextStyles.body.copyWith(
                            color: Styles.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Modular.to.navigate('/login-phone');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey[300]!,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            'Con Teléfono',
                            textAlign: TextAlign.center,
                            style: TextStyles.body.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
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
                  keyboardType: TextInputType.emailAddress,
                  // Validación de campo requerido
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'El correo es requerido.';
                    }
                    if (!value.contains('@')) {
                      return 'Ingrese un correo válido.';
                    }
                    return null;
                  },
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
                  // Validación de campo requerido
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'La contraseña es requerida.';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    hintStyle: const TextStyle(
                      color: Color(0xFFD9D9D9),
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    // Si hay un error, el borde cambia a rojo
                    errorBorder: _passwordError != null
                        ? OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Styles.errorColor,
                              width: 1,
                            ),
                          )
                        : null,
                    focusedErrorBorder: _passwordError != null
                        ? OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Styles.errorColor,
                              width: 2,
                            ),
                          )
                        : null,
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
                // Mostrar el mensaje de error de credenciales aquí
                if (_passwordError != null)
                  Padding(
                    padding: EdgeInsets.only(top: Styles.spacingXSmall),
                    child: Text(
                      _passwordError!,
                      style: TextStyles.caption.copyWith(
                        color: Styles.errorColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                SizedBox(
                  height:
                      Styles.spacingXLarge -
                      (_passwordError != null ? Styles.spacingXSmall : 0),
                ), // Ajustar el espacio si se muestra el error

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    // Deshabilita el botón durante la carga
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Styles.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      disabledBackgroundColor: Styles.primaryColor.withAlpha(
                        153,
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Iniciar Sesión',
                            style: TextStyles.button.copyWith(fontSize: 16),
                          ),
                  ),
                ),
                SizedBox(height: Styles.spacingXLarge),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "¿No tienes una cuenta? ",
                      style: TextStyles.body.copyWith(
                        color: Styles.textSecondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: _goToRegister,
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
                SizedBox(height: Styles.spacingMedium),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      Text(
                        '¿Eres una empresa o agente inmobiliario? ',
                        style: TextStyles.body.copyWith(
                          color: Styles.textSecondary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Modular.to.navigate('/inmobiliaria-login'),
                        child: Text(
                          'Ingresa aquí',
                          style: TextStyles.body.copyWith(
                            color: Styles.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        ' o ',
                        style: TextStyles.body.copyWith(
                          color: Styles.textSecondary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            Modular.to.navigate('/inmobiliaria-register'),
                        child: Text(
                          'Regístrate aquí',
                          style: TextStyles.body.copyWith(
                            color: Styles.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
