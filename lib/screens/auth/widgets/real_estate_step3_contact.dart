// filepath: lib/screens/auth/widgets/real_estate_step3_contact.dart
import 'package:flutter/material.dart';
import '../../../theme/theme.dart';

class RealEstateStep3Contact extends StatefulWidget {
  final bool isAgent;
  final TextEditingController addressController;
  final TextEditingController representativeController;
  final List<TextEditingController> phoneControllers;
  final VoidCallback onAddPhone;
  final Function(int) onRemovePhone;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  const RealEstateStep3Contact({
    super.key,
    required this.isAgent,
    required this.addressController,
    required this.representativeController,
    required this.phoneControllers,
    required this.onAddPhone,
    required this.onRemovePhone,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.isLoading,
    required this.errorMessage,
    required this.onSubmit,
    required this.onBack,
  });

  @override
  State<RealEstateStep3Contact> createState() => _RealEstateStep3ContactState();
}

class _RealEstateStep3ContactState extends State<RealEstateStep3Contact> {
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  void _handleSubmit() {
    if (_formKey.currentState!.validate()) {
      // Check password match
      if (widget.passwordController.text !=
          widget.confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Las contraseñas no coinciden'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      widget.onSubmit();
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
              'Contacto y Credenciales',
              style: TextStyles.title.copyWith(
                color: Styles.primaryColor,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Completa tu información de contacto',
              style: TextStyles.body.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: Styles.spacingLarge * 1.5),

            // Address
            TextFormField(
              controller: widget.addressController,
              decoration: InputDecoration(
                labelText: 'Dirección',
                hintText: 'Dirección de la oficina principal',
                prefixIcon: const Icon(Icons.location_on),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              maxLines: 2,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'La dirección es requerida';
                }
                if (value.trim().length < 10) {
                  return 'La dirección es muy corta';
                }
                if (value.trim().length > 200) {
                  return 'La dirección es muy larga (máximo 200 caracteres)';
                }
                return null;
              },
            ),
            SizedBox(height: Styles.spacingMedium),

            // Representative name (only for companies)
            if (!widget.isAgent) ...[
              TextFormField(
                controller: widget.representativeController,
                decoration: InputDecoration(
                  labelText: 'Nombre del Representante Legal',
                  hintText: 'Nombre completo del representante',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El nombre del representante es requerido';
                  }
                  if (value.trim().length < 3) {
                    return 'Nombre muy corto';
                  }
                  return null;
                },
              ),
              SizedBox(height: Styles.spacingMedium),
            ],

            // Phone numbers section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Teléfonos',
                  style: TextStyles.subtitle.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Styles.textPrimary,
                  ),
                ),
                Text(
                  '${widget.phoneControllers.length}/5',
                  style: TextStyles.caption.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Phone fields
            ...widget.phoneControllers.asMap().entries.map((entry) {
              final index = entry.key;
              final controller = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: controller,
                        decoration: InputDecoration(
                          labelText: 'Teléfono ${index + 1}',
                          hintText: '70123456',
                          prefixIcon: const Icon(Icons.phone),
                          suffixIcon: widget.phoneControllers.length > 1
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => widget.onRemovePhone(index),
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (index == 0 &&
                              (value == null || value.trim().isEmpty)) {
                            return 'Al menos un teléfono es requerido';
                          }
                          if (value != null && value.trim().isNotEmpty) {
                            if (!RegExp(r'^[0-9]{8}$').hasMatch(value.trim())) {
                              return 'Debe tener 8 dígitos';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),

            // Add phone button
            if (widget.phoneControllers.length < 5)
              OutlinedButton.icon(
                onPressed: widget.onAddPhone,
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Agregar otro teléfono'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: Styles.primaryColor),
                  foregroundColor: Styles.primaryColor,
                ),
              ),
            SizedBox(height: Styles.spacingLarge),

            // Email
            TextFormField(
              controller: widget.emailController,
              decoration: InputDecoration(
                labelText: 'Correo Electrónico',
                hintText: 'correo@ejemplo.com',
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El correo es requerido';
                }
                if (!RegExp(
                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                ).hasMatch(value.trim())) {
                  return 'Correo inválido';
                }
                return null;
              },
            ),
            SizedBox(height: Styles.spacingMedium),

            // Password
            TextFormField(
              controller: widget.passwordController,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                hintText: 'Mínimo 6 caracteres',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              obscureText: _obscurePassword,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'La contraseña es requerida';
                }
                if (value.length < 6) {
                  return 'Mínimo 6 caracteres';
                }
                return null;
              },
            ),
            SizedBox(height: Styles.spacingMedium),

            // Confirm password
            TextFormField(
              controller: widget.confirmPasswordController,
              decoration: InputDecoration(
                labelText: 'Confirmar Contraseña',
                hintText: 'Repite la contraseña',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              obscureText: _obscureConfirmPassword,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Confirma tu contraseña';
                }
                if (value != widget.passwordController.text) {
                  return 'Las contraseñas no coinciden';
                }
                return null;
              },
            ),

            // Error message
            if (widget.errorMessage != null) ...[
              SizedBox(height: Styles.spacingMedium),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.errorMessage!,
                        style: TextStyles.caption.copyWith(
                          color: Colors.red[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(height: Styles.spacingLarge * 2),

            // Navigation buttons
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    onPressed: widget.isLoading ? null : widget.onBack,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Styles.primaryColor),
                    ),
                    child: const Icon(Icons.arrow_back, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: ElevatedButton(
                    onPressed: widget.isLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Styles.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: widget.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Completar Registro',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
