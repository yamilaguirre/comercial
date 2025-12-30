import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/image_service.dart';

class InmobiliariaEditProfileScreen extends StatefulWidget {
  const InmobiliariaEditProfileScreen({super.key});

  @override
  State<InmobiliariaEditProfileScreen> createState() =>
      _InmobiliariaEditProfileScreenState();
}

class _InmobiliariaEditProfileScreenState
    extends State<InmobiliariaEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _documentNumberController =
      TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  List<TextEditingController> _phoneControllers = [TextEditingController()];
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _representativeController =
      TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isAgent = false;

  String? _originalEmail;
  String? _userId;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _documentNumberController.dispose();
    _addressController.dispose();
    for (var controller in _phoneControllers) {
      controller.dispose();
    }
    _emailController.dispose();
    _representativeController.dispose();
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

        // Cargar teléfonos
        final phoneNumbers = (userData['phoneNumbers'] as List<dynamic>?) ?? [];
        if (phoneNumbers.isNotEmpty) {
          _phoneControllers = phoneNumbers
              .map((phone) => TextEditingController(text: phone.toString()))
              .toList();
        }

        setState(() {
          _isAgent = userData['isAgent'] ?? false;
          _companyNameController.text = userData['companyName'] ?? '';
          _documentNumberController.text = userData['documentNumber'] ?? '';
          _addressController.text = userData['address'] ?? '';
          _emailController.text = userData['email'] ?? user.email ?? '';
          _representativeController.text = userData['representativeName'] ?? '';
          _photoUrl = userData['companyLogo'] ?? userData['photoURL'];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Error al cargar datos: $e');
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (image == null) return;

      setState(() => _isUploadingPhoto = true);

      final imageUrl = await ImageService.uploadImageToApi(
        image,
        folderPath: 'company_logos/$_userId',
      );

      await FirebaseFirestore.instance.collection('users').doc(_userId).update({
        'companyLogo': imageUrl,
        'photoURL': imageUrl,
      });

      final user = FirebaseAuth.instance.currentUser;
      await user?.updatePhotoURL(imageUrl);

      setState(() {
        _photoUrl = imageUrl;
        _isUploadingPhoto = false;
      });

      _showSuccessSnackBar('Logo actualizado exitosamente');
    } catch (e) {
      setState(() => _isUploadingPhoto = false);
      _showErrorSnackBar('Error al subir logo: $e');
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

    final wantsPasswordChange = _newPasswordController.text.isNotEmpty;
    if (wantsPasswordChange && _currentPasswordController.text.isEmpty) {
      _showErrorSnackBar('Ingresa tu contraseña actual para cambiarla');
      return;
    }

    setState(() => _isSaving = true);

    try {
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

      // Recopilar teléfonos
      final phones = _phoneControllers
          .map((c) => c.text.trim())
          .where((p) => p.isNotEmpty)
          .toList();

      await FirebaseFirestore.instance.collection('users').doc(_userId).update({
        'companyName': _companyNameController.text.trim(),
        'displayName': _companyNameController.text.trim(),
        'documentNumber': _documentNumberController.text.trim(),
        'address': _addressController.text.trim(),
        'phoneNumbers': phones,
        'email': _emailController.text.trim(),
        'representativeName': _isAgent
            ? null
            : _representativeController.text.trim(),
      });

      await user.updateDisplayName(_companyNameController.text.trim());

      if (_emailController.text.trim() != _originalEmail) {
        await user.verifyBeforeUpdateEmail(_emailController.text.trim());
        _showInfoSnackBar(
          'Se ha enviado un correo de verificación a ${_emailController.text.trim()}',
        );
      }

      if (wantsPasswordChange) {
        await user.updatePassword(_newPasswordController.text);
        _showSuccessSnackBar('Contraseña actualizada exitosamente');
      }

      setState(() => _isSaving = false);
      _showSuccessSnackBar('Perfil actualizado exitosamente');

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
          'Editar Perfil Empresarial',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Styles.primaryColor),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
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
                              // Logo de empresa
                              Center(
                                child: Stack(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Styles.primaryColor,
                                          width: 3,
                                        ),
                                      ),
                                      child: CircleAvatar(
                                        radius: 60,
                                        backgroundColor: Colors.grey[200],
                                        backgroundImage: _photoUrl != null
                                            ? NetworkImage(_photoUrl!)
                                            : null,
                                        child: _photoUrl == null
                                            ? Icon(
                                                Icons.business,
                                                size: 60,
                                                color: Colors.grey[400],
                                              )
                                            : null,
                                      ),
                                    ),
                                    if (_isUploadingPhoto)
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: GestureDetector(
                                        onTap: _isUploadingPhoto
                                            ? null
                                            : _pickAndUploadPhoto,
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Styles.primaryColor,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.camera_alt,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: Styles.spacingXLarge),

                              // Información de la Empresa
                              _buildSectionTitle('Información de la Empresa'),
                              SizedBox(height: Styles.spacingMedium),

                              _buildLabel('Nombre de la Empresa'),
                              SizedBox(height: Styles.spacingSmall),
                              TextFormField(
                                controller: _companyNameController,
                                decoration: _buildInputDecoration(
                                  hintText: 'Inmobiliaria ABC',
                                  prefixIcon: Icons.business_outlined,
                                ),
                                validator: (v) =>
                                    v!.isEmpty ? 'Requerido' : null,
                              ),
                              SizedBox(height: Styles.spacingMedium),

                              _buildLabel(
                                _isAgent ? 'Número de CI' : 'Número de NIT',
                              ),
                              SizedBox(height: Styles.spacingSmall),
                              TextFormField(
                                controller: _documentNumberController,
                                decoration: _buildInputDecoration(
                                  hintText: _isAgent ? 'CI' : 'NIT',
                                  prefixIcon: Icons.badge_outlined,
                                ),
                                keyboardType: TextInputType.number,
                                validator: (v) =>
                                    v!.isEmpty ? 'Requerido' : null,
                              ),
                              SizedBox(height: Styles.spacingMedium),

                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    _isAgent
                                        ? 'Agente Inmobiliario'
                                        : 'Inmobiliaria',
                                    style: TextStyles.caption.copyWith(
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: Styles.spacingMedium),

                              _buildLabel('Dirección'),
                              SizedBox(height: Styles.spacingSmall),
                              TextFormField(
                                controller: _addressController,
                                decoration: _buildInputDecoration(
                                  hintText: 'Dirección de la oficina',
                                  prefixIcon: Icons.location_on_outlined,
                                ),
                                validator: (v) =>
                                    v!.isEmpty ? 'Requerido' : null,
                              ),
                              SizedBox(height: Styles.spacingMedium),

                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildLabel('Teléfonos'),
                                  if (_phoneControllers.length < 5)
                                    TextButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _phoneControllers.add(
                                            TextEditingController(),
                                          );
                                        });
                                      },
                                      icon: Icon(Icons.add, size: 18),
                                      label: Text('Agregar'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Styles.primaryColor,
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: Styles.spacingSmall),
                              ..._phoneControllers.asMap().entries.map((entry) {
                                final index = entry.key;
                                final controller = entry.value;
                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom: Styles.spacingMedium,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: controller,
                                          decoration: _buildInputDecoration(
                                            hintText: '+591 XXXXXXXX',
                                            prefixIcon: Icons.phone_outlined,
                                          ),
                                          keyboardType: TextInputType.phone,
                                          validator: (v) {
                                            if (index == 0 && v!.isEmpty) {
                                              return 'Al menos un teléfono es requerido';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      if (_phoneControllers.length > 1)
                                        IconButton(
                                          onPressed: () {
                                            setState(() {
                                              controller.dispose();
                                              _phoneControllers.removeAt(index);
                                            });
                                          },
                                          icon: Icon(
                                            Icons.remove_circle_outline,
                                            color: Colors.red,
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }),

                              if (!_isAgent) ...[
                                _buildLabel('Representante Legal'),
                                SizedBox(height: Styles.spacingSmall),
                                TextFormField(
                                  controller: _representativeController,
                                  decoration: _buildInputDecoration(
                                    hintText: 'Nombre completo',
                                    prefixIcon: Icons.person_outline,
                                  ),
                                  validator: (v) => !_isAgent && v!.isEmpty
                                      ? 'Requerido'
                                      : null,
                                ),
                                SizedBox(height: Styles.spacingMedium),
                              ],

                              _buildLabel('Correo electrónico'),
                              SizedBox(height: Styles.spacingSmall),
                              TextFormField(
                                controller: _emailController,
                                decoration: _buildInputDecoration(
                                  hintText: 'empresa@ejemplo.com',
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
