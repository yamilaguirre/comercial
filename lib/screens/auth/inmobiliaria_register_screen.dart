import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/auth_provider.dart';
import '../../theme/theme.dart';

class InmobiliariaRegisterScreen extends StatefulWidget {
  const InmobiliariaRegisterScreen({super.key});

  @override
  State<InmobiliariaRegisterScreen> createState() => _InmobiliariaRegisterScreenState();
}

class _InmobiliariaRegisterScreenState extends State<InmobiliariaRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _rucController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _representativeNameController = TextEditingController();
  
  final AuthService _authService = Modular.get<AuthService>();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _companyNameController.dispose();
    _rucController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _representativeNameController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Las contraseñas no coinciden';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = userCredential.user;

      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': _emailController.text.trim(),
          'displayName': _companyNameController.text.trim(),
          'role': 'inmobiliaria_empresa',
          'companyName': _companyNameController.text.trim(),
          'ruc': _rucController.text.trim(),
          'address': _addressController.text.trim(),
          'phoneNumber': _phoneController.text.trim(),
          'representativeName': _representativeNameController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'isVerified': false,
        });

        await _authService.signOut();

        if (mounted) {
          Modular.to.navigate('/inmobiliaria-login');
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al registrar: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          Modular.to.navigate('/login');
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Styles.textPrimary),
          onPressed: () => Modular.to.pop(),
        ),
        title: Text(
          'Registro de Inmobiliaria',
          style: TextStyles.subtitle.copyWith(
            color: Styles.textPrimary,
            fontWeight: FontWeight.bold,
          ),
          ),
        ),
        body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(Styles.spacingLarge),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Información de la Empresa',
                  style: TextStyles.subtitle.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Styles.primaryColor,
                  ),
                ),
                SizedBox(height: Styles.spacingLarge),
                _buildTextField(
                  controller: _companyNameController,
                  label: 'Nombre de la Empresa',
                  hint: 'Ej: Inmobiliaria ABC',
                  validator: (v) => v?.isEmpty ?? true ? 'Campo requerido' : null,
                ),
                SizedBox(height: Styles.spacingMedium),
                _buildTextField(
                  controller: _rucController,
                  label: 'RUC/NIT',
                  hint: 'Número de identificación tributaria',
                  validator: (v) => v?.isEmpty ?? true ? 'Campo requerido' : null,
                ),
                SizedBox(height: Styles.spacingMedium),
                _buildTextField(
                  controller: _addressController,
                  label: 'Dirección',
                  hint: 'Dirección de la oficina principal',
                  validator: (v) => v?.isEmpty ?? true ? 'Campo requerido' : null,
                ),
                SizedBox(height: Styles.spacingMedium),
                _buildTextField(
                  controller: _phoneController,
                  label: 'Teléfono',
                  hint: '+591 XXXXXXXX',
                  keyboardType: TextInputType.phone,
                  validator: (v) => v?.isEmpty ?? true ? 'Campo requerido' : null,
                ),
                SizedBox(height: Styles.spacingMedium),
                _buildTextField(
                  controller: _representativeNameController,
                  label: 'Nombre del Representante Legal',
                  hint: 'Nombre completo',
                  validator: (v) => v?.isEmpty ?? true ? 'Campo requerido' : null,
                ),
                SizedBox(height: Styles.spacingLarge),
                Text(
                  'Credenciales de Acceso',
                  style: TextStyles.subtitle.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Styles.primaryColor,
                  ),
                ),
                SizedBox(height: Styles.spacingLarge),
                _buildTextField(
                  controller: _emailController,
                  label: 'Correo Electrónico',
                  hint: 'empresa@ejemplo.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v?.isEmpty ?? true) return 'Campo requerido';
                    if (!v!.contains('@')) return 'Correo inválido';
                    return null;
                  },
                ),
                SizedBox(height: Styles.spacingMedium),
                _buildTextField(
                  controller: _passwordController,
                  label: 'Contraseña',
                  hint: '••••••••',
                  obscureText: true,
                  validator: (v) {
                    if (v?.isEmpty ?? true) return 'Campo requerido';
                    if (v!.length < 6) return 'Mínimo 6 caracteres';
                    return null;
                  },
                ),
                SizedBox(height: Styles.spacingMedium),
                _buildTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirmar Contraseña',
                  hint: '••••••••',
                  obscureText: true,
                  validator: (v) => v?.isEmpty ?? true ? 'Campo requerido' : null,
                ),
                if (_errorMessage != null)
                  Padding(
                    padding: EdgeInsets.only(top: Styles.spacingMedium),
                    child: Text(
                      _errorMessage!,
                      style: TextStyles.caption.copyWith(
                        color: Styles.errorColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                SizedBox(height: Styles.spacingXLarge),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Styles.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Registrar Empresa', style: TextStyle(fontSize: 16)),
                  ),
                ),
                SizedBox(height: Styles.spacingMedium),
                Center(
                  child: GestureDetector(
                    onTap: () => Modular.to.navigate('/inmobiliaria-login'),
                    child: Text(
                      '¿Ya tienes cuenta? Inicia sesión',
                      style: TextStyles.body.copyWith(
                        color: Styles.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyles.body.copyWith(
            fontWeight: FontWeight.w500,
            color: Styles.textPrimary,
          ),
        ),
        SizedBox(height: Styles.spacingSmall),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
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
          ),
        ),
      ],
    );
  }
}
