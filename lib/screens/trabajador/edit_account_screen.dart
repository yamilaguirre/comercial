// filepath: lib/screens/trabajador/edit_account_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/theme.dart';
import '../../providers/auth_provider.dart';

class EditAccountScreen extends StatefulWidget {
  const EditAccountScreen({super.key});

  @override
  State<EditAccountScreen> createState() => _EditAccountScreenState();
}

class _EditAccountScreenState extends State<EditAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  String? _originalEmail;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    if (user == null) {
      Modular.to.navigate('/login');
      return;
    }

    setState(() {
      _userId = user.uid;
      _originalEmail = user.email;
    });

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;

        setState(() {
          _nameController.text =
              userData['displayName'] ?? user.displayName ?? '';
          _emailController.text = userData['email'] ?? user.email ?? '';
          _phoneController.text = userData['phone'] ?? '';
          _isLoading = false;
        });
      } else {
        setState(() {
          _nameController.text = user.displayName ?? '';
          _emailController.text = user.email ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Error al cargar datos: $e');
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    if (user == null) {
      _showErrorSnackBar('Usuario no autenticado');
      return;
    }

    // Si quiere cambiar la contraseña, debe proporcionar la actual
    final wantsPasswordChange = _newPasswordController.text.isNotEmpty;
    if (wantsPasswordChange && _currentPasswordController.text.isEmpty) {
      _showErrorSnackBar('Ingresa tu contraseña actual para cambiarla');
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Verificar contraseña actual si se proporciona
      if (_currentPasswordController.text.isNotEmpty) {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: _currentPasswordController.text,
        );

        try {
          await user.reauthenticateWithCredential(credential);
        } catch (e) {
          setState(() => _isSaving = false);
          _showErrorSnackBar('Contraseña actual incorrecta');
          return;
        }
      }

      // Actualizar datos en Firestore
      await FirebaseFirestore.instance.collection('users').doc(_userId).update({
        'displayName': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
      });

      // Actualizar displayName en Firebase Auth
      await user.updateDisplayName(_nameController.text.trim());

      // Actualizar email si cambió
      if (_emailController.text.trim() != _originalEmail) {
        await user.verifyBeforeUpdateEmail(_emailController.text.trim());
        _showInfoSnackBar(
          'Se ha enviado un correo de verificación a ${_emailController.text.trim()}',
        );
      }

      // Actualizar contraseña si se proporcionó una nueva
      if (wantsPasswordChange) {
        await user.updatePassword(_newPasswordController.text);
        _showSuccessSnackBar('Contraseña actualizada exitosamente');
      }

      setState(() => _isSaving = false);
      _showSuccessSnackBar('Cuenta actualizada exitosamente');

      // Esperar un poco para que el usuario vea el mensaje
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        Modular.to.pop();
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showErrorSnackBar('Error al actualizar: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Styles.successColor),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Styles.errorColor),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Styles.infoColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Styles.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Modular.to.pop(),
        ),
        title: const Text(
          'Editar Cuenta',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Styles.primaryColor),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                // Diseño responsivo: en pantallas grandes, limitar el ancho
                final isLargeScreen = constraints.maxWidth > 600;
                final contentPadding = isLargeScreen
                    ? Styles.spacingXLarge
                    : Styles.spacingMedium;

                return Center(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: isLargeScreen ? 600 : double.infinity,
                    ),
                    child: SafeArea(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(contentPadding),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Información de la cuenta
                              _buildSectionTitle('Información Personal'),
                              SizedBox(height: Styles.spacingMedium),

                              _buildLabel('Nombre completo'),
                              SizedBox(height: Styles.spacingSmall),
                              TextFormField(
                                controller: _nameController,
                                decoration: _buildInputDecoration(
                                  hintText: 'Ingresa tu nombre',
                                  prefixIcon: Icons.person_outline,
                                ),
                                validator: (v) =>
                                    v!.isEmpty ? 'Requerido' : null,
                              ),
                              SizedBox(height: Styles.spacingMedium),

                              _buildLabel('Correo electrónico'),
                              SizedBox(height: Styles.spacingSmall),
                              TextFormField(
                                controller: _emailController,
                                decoration: _buildInputDecoration(
                                  hintText: 'correo@ejemplo.com',
                                  prefixIcon: Icons.email_outlined,
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) => !v!.contains('@')
                                    ? 'Correo inválido'
                                    : null,
                              ),
                              if (_emailController.text != _originalEmail)
                                Padding(
                                  padding: EdgeInsets.only(
                                    top: Styles.spacingSmall,
                                  ),
                                  child: Text(
                                    'Se enviará un correo de verificación al nuevo email',
                                    style: TextStyles.caption.copyWith(
                                      color: Styles.infoColor,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              SizedBox(height: Styles.spacingMedium),

                              _buildLabel('Teléfono'),
                              SizedBox(height: Styles.spacingSmall),
                              TextFormField(
                                controller: _phoneController,
                                decoration: _buildInputDecoration(
                                  hintText: '70123456',
                                  prefixIcon: Icons.phone_outlined,
                                ),
                                keyboardType: TextInputType.phone,
                                validator: (v) =>
                                    v!.isEmpty ? 'Requerido' : null,
                              ),

                              SizedBox(height: Styles.spacingXLarge),
                              Divider(color: Colors.grey.shade300),
                              SizedBox(height: Styles.spacingLarge),

                              // Cambio de contraseña
                              _buildSectionTitle(
                                'Cambiar Contraseña (Opcional)',
                              ),
                              SizedBox(height: Styles.spacingSmall),
                              Text(
                                'Deja estos campos vacíos si no deseas cambiar tu contraseña',
                                style: TextStyles.caption.copyWith(
                                  color: Styles.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              SizedBox(height: Styles.spacingMedium),

                              _buildLabel('Contraseña actual'),
                              SizedBox(height: Styles.spacingSmall),
                              TextFormField(
                                controller: _currentPasswordController,
                                decoration: _buildInputDecoration(
                                  hintText: '••••••••',
                                  prefixIcon: Icons.lock_outline,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureCurrentPassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: Styles.textSecondary,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscureCurrentPassword =
                                          !_obscureCurrentPassword,
                                    ),
                                  ),
                                ),
                                obscureText: _obscureCurrentPassword,
                              ),
                              SizedBox(height: Styles.spacingMedium),

                              _buildLabel('Nueva contraseña'),
                              SizedBox(height: Styles.spacingSmall),
                              TextFormField(
                                controller: _newPasswordController,
                                decoration: _buildInputDecoration(
                                  hintText: '••••••••',
                                  prefixIcon: Icons.lock_outline,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureNewPassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: Styles.textSecondary,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscureNewPassword =
                                          !_obscureNewPassword,
                                    ),
                                  ),
                                ),
                                obscureText: _obscureNewPassword,
                                validator: (v) {
                                  if (v!.isEmpty) return null;
                                  if (v.length < 6)
                                    return 'Mínimo 6 caracteres';
                                  return null;
                                },
                              ),
                              SizedBox(height: Styles.spacingMedium),

                              _buildLabel('Confirmar nueva contraseña'),
                              SizedBox(height: Styles.spacingSmall),
                              TextFormField(
                                controller: _confirmPasswordController,
                                decoration: _buildInputDecoration(
                                  hintText: '••••••••',
                                  prefixIcon: Icons.lock_outline,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: Styles.textSecondary,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscureConfirmPassword =
                                          !_obscureConfirmPassword,
                                    ),
                                  ),
                                ),
                                obscureText: _obscureConfirmPassword,
                                validator: (v) {
                                  if (_newPasswordController.text.isEmpty)
                                    return null;
                                  if (v != _newPasswordController.text) {
                                    return 'Las contraseñas no coinciden';
                                  }
                                  return null;
                                },
                              ),

                              SizedBox(height: Styles.spacingXLarge),

                              // Botón Guardar
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _isSaving ? null : _handleSave,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Styles.primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: _isSaving
                                      ? const CircularProgressIndicator(
                                          color: Colors.white,
                                        )
                                      : Text(
                                          'Guardar Cambios',
                                          style: TextStyles.button.copyWith(
                                            fontSize: 16,
                                          ),
                                        ),
                                ),
                              ),

                              SizedBox(height: Styles.spacingLarge),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildSectionTitle(String text) => Text(
    text,
    style: TextStyles.subtitle.copyWith(
      fontWeight: FontWeight.bold,
      color: Styles.textPrimary,
    ),
  );

  Widget _buildLabel(String text) => Text(
    text,
    style: TextStyles.body.copyWith(
      fontWeight: FontWeight.w500,
      color: Styles.textPrimary,
    ),
  );

  InputDecoration _buildInputDecoration({
    required String hintText,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFFD9D9D9), fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: Styles.textSecondary, size: 20)
          : null,
      suffixIcon: suffixIcon,
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Styles.errorColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Styles.errorColor, width: 2),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: Styles.spacingMedium,
        vertical: Styles.spacingMedium,
      ),
    );
  }
}
