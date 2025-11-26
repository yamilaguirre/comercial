import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_modular/flutter_modular.dart'; // <-- Importación de Modular

import '../../providers/auth_provider.dart';
import '../../theme/theme.dart';
import '../../services/image_service.dart';
import 'dart:io'; // Necesario para FileImage

class EditProfileScreen extends StatefulWidget {
  // Nota: Al usar Modular, los argumentos se pasan en Modular.args.data
  final Map<String, dynamic>? userData;

  const EditProfileScreen({super.key, this.userData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;

  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();
  late String? _currentPhotoUrl;

  // Accede a los datos pasados por Modular.args
  Map<String, dynamic>? get _userData =>
      Modular.args.data is Map<String, dynamic>
      ? Modular.args.data as Map<String, dynamic>?
      : widget.userData;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: _userData?['displayName'] ?? '',
    );
    _phoneController = TextEditingController(
      text: _userData?['phoneNumber'] ?? '',
    );
    _emailController = TextEditingController(text: _userData?['email'] ?? '');
    _currentPhotoUrl = _userData?['photoURL'];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (pickedFile != null) {
      setState(() {
        _imageFile = pickedFile;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    String? newPhotoUrl = _currentPhotoUrl;

    if (_imageFile != null) {
      if (authService.currentUser == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subiendo foto...'),
          backgroundColor: Styles.infoColor,
        ),
      );

      try {
        final url = await ImageService.uploadAvatarToApi(
          _imageFile!,
          userId: authService.currentUser!.uid,
        );
        newPhotoUrl = url;
        setState(() {
          _currentPhotoUrl = url;
          _imageFile = null;
        });
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al subir foto: $e'),
              backgroundColor: Styles.errorColor,
            ),
          );
        return;
      }
    }

    final success = await authService.updateUserProfile(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      photoUrl: newPhotoUrl,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil actualizado'),
            backgroundColor: Styles.successColor,
          ),
        );
        // CORREGIDO: Usamos Modular.to.pop() para volver a la pantalla anterior
        Modular.to.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authService.errorMessage ?? 'Error al actualizar'),
            backgroundColor: Styles.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final avatarImage = _imageFile != null
        // Si hay una nueva imagen seleccionada, úsala desde el archivo
        ? FileImage(File(_imageFile!.path))
        // Si hay una URL actual, úsala. Si no hay, es null.
        : (_currentPhotoUrl != null ? NetworkImage(_currentPhotoUrl!) : null);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Editar Perfil',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.close),
          // CORREGIDO: Usamos Modular.to.pop()
          onPressed: () => Modular.to.pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Avatar minimalista
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[100],
                    backgroundImage: avatarImage as ImageProvider<Object>?,
                    child: avatarImage == null
                        ? Text(
                            _nameController.text.isNotEmpty
                                ? _nameController.text[0].toUpperCase()
                                : 'U',
                            style: TextStyle(
                              fontSize: 40,
                              color: Styles.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Styles.primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Cambiar foto',
              style: TextStyle(
                color: Styles.primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),

            // Formulario
            Padding(
              padding: EdgeInsets.all(Styles.spacingLarge),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Nombre Completo'),
                    TextFormField(
                      controller: _nameController,
                      decoration: _buildInputDecoration('Tu nombre'),
                      validator: (value) => value!.isEmpty ? 'Requerido' : null,
                    ),

                    SizedBox(height: Styles.spacingLarge),

                    _buildLabel('Teléfono'),
                    TextFormField(
                      controller: _phoneController,
                      decoration: _buildInputDecoration('Tu teléfono'),
                      keyboardType: TextInputType.phone,
                      validator: (value) => value!.isEmpty ? 'Requerido' : null,
                    ),

                    SizedBox(height: Styles.spacingLarge),

                    _buildLabel('Correo Electrónico'),
                    TextFormField(
                      controller: _emailController,
                      readOnly: true,
                      style: const TextStyle(color: Colors.grey),
                      decoration: _buildInputDecoration('Tu correo').copyWith(
                        fillColor: Colors.grey[50],
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                    ),

                    SizedBox(height: Styles.spacingXLarge),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: authService.isLoading ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Styles.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: authService.isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'Guardar Cambios',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: Color(0xFF374151),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Styles.primaryColor, width: 2),
      ),
    );
  }
}
