// filepath: lib/screens/auth/widgets/real_estate_step1_basic_info.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../theme/theme.dart';

class RealEstateStep1BasicInfo extends StatefulWidget {
  final TextEditingController nameController;
  final File? logoImage;
  final Function(File?) onLogoChanged;
  final VoidCallback onNext;

  const RealEstateStep1BasicInfo({
    super.key,
    required this.nameController,
    required this.logoImage,
    required this.onLogoChanged,
    required this.onNext,
  });

  @override
  State<RealEstateStep1BasicInfo> createState() =>
      _RealEstateStep1BasicInfoState();
}

class _RealEstateStep1BasicInfoState extends State<RealEstateStep1BasicInfo> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickLogo() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        widget.onLogoChanged(File(pickedFile.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar imagen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleNext() {
    if (_formKey.currentState!.validate()) {
      if (widget.logoImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor selecciona un logo o imagen'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      widget.onNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(Styles.spacingLarge),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            Text(
              'Información Básica',
              style: TextStyles.title.copyWith(
                color: Styles.primaryColor,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Comencemos con tu nombre y logo',
              style: TextStyles.body.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: Styles.spacingLarge * 2),

            // Logo picker
            Center(
              child: GestureDetector(
                onTap: _pickLogo,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.logoImage != null
                          ? Styles.primaryColor
                          : Colors.grey[400]!,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 2,
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: widget.logoImage != null
                      ? ClipOval(
                          child: Image.file(
                            widget.logoImage!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate,
                              size: 50,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Agregar Logo',
                              style: TextStyles.caption.copyWith(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            SizedBox(height: Styles.spacingLarge),

            // Hint text
            if (widget.logoImage != null)
              Center(
                child: TextButton.icon(
                  onPressed: _pickLogo,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Cambiar imagen'),
                  style: TextButton.styleFrom(
                    foregroundColor: Styles.primaryColor,
                  ),
                ),
              ),
            SizedBox(height: Styles.spacingLarge),

            // Name field
            TextFormField(
              controller: widget.nameController,
              decoration: InputDecoration(
                labelText: 'Nombre de la Inmobiliaria o Agente',
                hintText: 'Ej: Inmobiliaria Santa Cruz',
                prefixIcon: const Icon(Icons.business),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Este campo es requerido';
                }
                if (value.trim().length < 3) {
                  return 'El nombre debe tener al menos 3 caracteres';
                }
                if (value.trim().length > 100) {
                  return 'El nombre es muy largo (máximo 100 caracteres)';
                }
                return null;
              },
            ),
            SizedBox(height: Styles.spacingLarge * 2),

            // Next button
            ElevatedButton(
              onPressed: _handleNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: Styles.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Siguiente',
                    style: TextStyles.button.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
