// filepath: lib/screens/auth/complete_profile_google_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../theme/theme.dart';

class CompleteProfileGoogleScreen extends StatefulWidget {
  const CompleteProfileGoogleScreen({super.key});

  @override
  State<CompleteProfileGoogleScreen> createState() =>
      _CompleteProfileGoogleScreenState();
}

class _CompleteProfileGoogleScreenState
    extends State<CompleteProfileGoogleScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  final User? _user = FirebaseAuth.instance.currentUser;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleCompleteProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_user == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final phone = '+591${_phoneController.text.trim()}';

      // 1. Guardar datos en Firestore
      await FirebaseFirestore.instance.collection('users').doc(_user.uid).set({
        'uid': _user.uid,
        'email': _user.email,
        'displayName': _user.displayName,
        'photoURL': _user.photoURL,
        'phoneNumber': phone,
        'role': 'cliente',
        'status': 'cliente',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'isActive': true,
        'needsProfileCompletion': false,
        'authMethod': 'google',
      }, SetOptions(merge: true));

      // 2. Nota: Firebase Auth no permite establecer contraseña a una cuenta de Google directamente
      // sin convertirla en Email/Password. Pero el usuario pidió contraseña para que el Admin use esos datos.
      // Se guardará la contraseña en Firestore (encriptada o plana según requerimiento anterior,
      // pero aquí la guardaremos plana ya que es para "referencia del admin").
      // ADVERTENCIA: En un entorno real esto debería ser manejado de forma segura.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_user.uid)
          .update({
            'password': _passwordController.text, // Para el admin
          });

      if (mounted) {
        Modular.to.navigate('/select-role');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al completar perfil: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Styles.textPrimary),
          onPressed: () => Modular.to.navigate('/login'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: SvgPicture.asset(
                    'assets/images/Logo P2.svg',
                    height: 50,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Completa tu Perfil',
                  textAlign: TextAlign.center,
                  style: TextStyles.title.copyWith(
                    fontSize: 24,
                    color: Styles.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Hola ${_user?.displayName ?? ""}, solo necesitamos unos datos más para empezar.',
                  textAlign: TextAlign.center,
                  style: TextStyles.body.copyWith(color: Styles.textSecondary),
                ),
                const SizedBox(height: 40),

                Text(
                  'Número de Referencia (Celular)',
                  style: TextStyles.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Styles.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[50],
                      ),
                      child: const Text('+591', style: TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: '70000000',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFFE0E0E0),
                            ),
                          ),
                        ),
                        validator: (value) =>
                            (value == null || value.length < 8)
                            ? 'Número inválido'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Text(
                  'Crea una Contraseña',
                  style: TextStyles.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Styles.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) => (value == null || value.length < 6)
                      ? 'Mínimo 6 caracteres'
                      : null,
                ),
                const SizedBox(height: 24),

                Text(
                  'Confirmar Contraseña',
                  style: TextStyles.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Styles.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                  ),
                  validator: (value) => value != _passwordController.text
                      ? 'Las contraseñas no coinciden'
                      : null,
                ),

                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Styles.errorColor),
                      textAlign: TextAlign.center,
                    ),
                  ),

                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleCompleteProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Styles.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Completar Registro',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
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
