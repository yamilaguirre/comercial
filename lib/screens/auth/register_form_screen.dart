import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/theme.dart';
import '../../providers/auth_provider.dart';

class RegisterFormScreen extends StatefulWidget {
  final String userType;
  const RegisterFormScreen({super.key, required this.userType});

  @override
  State<RegisterFormScreen> createState() => _RegisterFormScreenState();
}

class _RegisterFormScreenState extends State<RegisterFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _acceptedTerms = false;

  // Título genérico ya que el rol se define después
  String get _userTypeTitle {
    return 'Registro';
  }

  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Acepta los términos y condiciones'),
          backgroundColor: Styles.errorColor,
        ),
      );
      return;
    }

    // Obtenemos el servicio de autenticación
    final authService = Provider.of<AuthService>(context, listen: false);

    // Registramos al usuario.
    // NOTA: Aunque pasemos 'cliente' (o lo que venga en userType),
    // tu AuthService ya está configurado para forzar el rol y status a 'cliente'
    // en la función _saveUserToFirestore, garantizando que vaya a la selección de rol.
    final user = await authService.registerWithEmailPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      displayName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      userRole: 'cliente',
    );

    if (user != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Registro exitoso!'),
          backgroundColor: Styles.successColor,
        ),
      );
      // El AppRouter detectará el nuevo estado (logueado + rol cliente)
      // y redirigirá automáticamente a /select-role.
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authService.errorMessage ?? 'Error al registrarse'),
          backgroundColor: Styles.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Escuchamos cambios para mostrar loading en el botón
    final authService = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Styles.textPrimary),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/register'),
        ),
        title: Text(
          _userTypeTitle,
          style: TextStyles.subtitle.copyWith(
            color: Styles.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: Styles.spacingLarge,
            vertical: Styles.spacingLarge,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Image.asset(
                    'assets/images/logoColor.png',
                    height: 50,
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(height: Styles.spacingXLarge),
                Text(
                  'Crear tu cuenta',
                  style: TextStyles.title.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: Styles.spacingXLarge),

                // Inputs
                _buildLabel('Nombre completo'),
                SizedBox(height: Styles.spacingSmall),
                TextFormField(
                  controller: _nameController,
                  decoration: _buildInputDecoration(hintText: 'ej: Juan Pérez'),
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                ),
                SizedBox(height: Styles.spacingLarge),

                _buildLabel('Correo electrónico'),
                SizedBox(height: Styles.spacingSmall),
                TextFormField(
                  controller: _emailController,
                  decoration: _buildInputDecoration(
                    hintText: 'ej: juan@email.com',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      !v!.contains('@') ? 'Correo inválido' : null,
                ),
                SizedBox(height: Styles.spacingLarge),

                _buildLabel('Teléfono'),
                SizedBox(height: Styles.spacingSmall),
                TextFormField(
                  controller: _phoneController,
                  decoration: _buildInputDecoration(hintText: 'ej: 70123456'),
                  keyboardType: TextInputType.phone,
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                ),
                SizedBox(height: Styles.spacingLarge),

                _buildLabel('Contraseña'),
                SizedBox(height: Styles.spacingSmall),
                TextFormField(
                  controller: _passwordController,
                  decoration: _buildInputDecoration(hintText: '••••••••'),
                  obscureText: true,
                  validator: (v) =>
                      v!.length < 6 ? 'Mínimo 6 caracteres' : null,
                ),
                SizedBox(height: Styles.spacingLarge),

                _buildLabel('Confirmar contraseña'),
                SizedBox(height: Styles.spacingSmall),
                TextFormField(
                  controller: _confirmController,
                  decoration: _buildInputDecoration(hintText: '••••••••'),
                  obscureText: true,
                  validator: (v) =>
                      v != _passwordController.text ? 'No coinciden' : null,
                ),
                SizedBox(height: Styles.spacingLarge),

                // Términos
                Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _acceptedTerms,
                        onChanged: (v) =>
                            setState(() => _acceptedTerms = v ?? false),
                        activeColor: Styles.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    SizedBox(width: Styles.spacingSmall),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _acceptedTerms = !_acceptedTerms),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyles.caption.copyWith(
                              color: Styles.textSecondary,
                            ),
                            children: [
                              const TextSpan(text: 'Acepto los '),
                              TextSpan(
                                text: 'términos y condiciones',
                                style: TextStyle(
                                  color: Styles.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: Styles.spacingXLarge),

                // Botón Registrar
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: authService.isLoading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Styles.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: authService.isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Registrarse',
                            style: TextStyles.button.copyWith(fontSize: 16),
                          ),
                  ),
                ),

                SizedBox(height: Styles.spacingLarge),

                // Ir a Login
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
                      onTap: () => context.go('/login'),
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
      ),
    );
  }

  Widget _buildLabel(String text) => Text(
    text,
    style: TextStyles.body.copyWith(
      fontWeight: FontWeight.w500,
      color: Styles.textPrimary,
    ),
  );

  InputDecoration _buildInputDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFFD9D9D9), fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Styles.primaryColor, width: 2),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: Styles.spacingMedium,
        vertical: Styles.spacingMedium,
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
