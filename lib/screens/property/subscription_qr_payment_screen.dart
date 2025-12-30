import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/subscription_plan_model.dart';
import '../../services/subscription_service.dart';
import '../../providers/auth_provider.dart';
import '../../theme/theme.dart';

class SubscriptionQRPaymentScreen extends StatefulWidget {
  const SubscriptionQRPaymentScreen({super.key});

  @override
  State<SubscriptionQRPaymentScreen> createState() =>
      _SubscriptionQRPaymentScreenState();
}

class _SubscriptionQRPaymentScreenState
    extends State<SubscriptionQRPaymentScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final ImagePicker _imagePicker = ImagePicker();

  List<SubscriptionPlan> _plans = [];
  SubscriptionPlan? _selectedPlan;
  File? _selectedImage;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      final plans = await _subscriptionService.getActivePlans();
      print('Planes cargados: ${plans.length}');
      for (var plan in plans) {
        print('Plan: ${plan.name} - ${plan.price} ${plan.currency}');
      }

      setState(() {
        _plans = plans;
        _isLoading = false;
        // Auto-select first plan if available
        if (plans.isNotEmpty) {
          _selectedPlan = plans.first;
        }
      });

      if (plans.isEmpty) {
        _showErrorDialog(
          'No hay planes de suscripción disponibles actualmente.',
        );
      }
    } catch (e) {
      print('Error al cargar planes: $e');
      setState(() => _isLoading = false);
      _showErrorDialog('Error al cargar los planes: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      _showErrorDialog('Error al seleccionar imagen: $e');
    }
  }

  Future<void> _submitRequest() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona tu comprobante de pago'),
        ),
      );
      return;
    }

    if (_selectedPlan == null) {
      _showErrorDialog('Por favor selecciona un plan de suscripción');
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    if (user == null) {
      Modular.to.navigate('/login');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final receiptUrl = await _subscriptionService.uploadPaymentProof(
        _selectedImage!,
        user.uid,
      );

      await _subscriptionService.createSubscriptionRequest(
        userId: user.uid,
        planId: _selectedPlan!.id,
        planName: _selectedPlan!.name,
        amount: _selectedPlan!.price,
        receiptUrl: receiptUrl,
      );

      setState(() => _isSubmitting = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solicitud enviada con éxito'),
            backgroundColor: Colors.green,
          ),
        );
        Modular.to.navigate('/property/subscription-status');
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      _showErrorDialog('Error al enviar solicitud: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Suscripción Premium'),
          backgroundColor: Styles.primaryColor,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _plans.isEmpty
            ? const Center(child: Text('No hay planes disponibles'))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Plan selection section
                    const Text(
                      'Selecciona tu Plan',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Debug info
                    if (_plans.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'No se encontraron planes activos. Verifica la colección "subscription_plans" en Firestore.',
                          style: TextStyle(color: Colors.orange[900]),
                        ),
                      ),

                    // Plans list
                    ..._plans.map((plan) => _buildPlanCard(plan)),

                    if (_selectedPlan != null) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Pasos para suscribirte:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildStep('1', 'Escanea el código QR o descárgalo'),
                      _buildStep(
                        '2',
                        'Realiza el pago según las instrucciones',
                      ),
                      _buildStep('3', 'Sube tu comprobante de pago'),
                      _buildStep(
                        '4',
                        'Espera la confirmación del administrador',
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Código QR para Pago',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: _selectedPlan!.qrCodeUrl.isNotEmpty
                              ? Image.network(
                                  _selectedPlan!.qrCodeUrl,
                                  width: 250,
                                  height: 250,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.error_outline,
                                      size: 100,
                                      color: Colors.red,
                                    );
                                  },
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                        if (loadingProgress == null)
                                          return child;
                                        return const SizedBox(
                                          width: 250,
                                          height: 250,
                                          child: Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        );
                                      },
                                )
                              : const Icon(
                                  Icons.qr_code_2,
                                  size: 250,
                                  color: Colors.grey,
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Comprobante de Pago',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_selectedImage != null) ...[
                        Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _selectedImage!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isSubmitting ? null : _pickImage,
                          icon: Icon(
                            _selectedImage == null
                                ? Icons.upload_file
                                : Icons.edit,
                          ),
                          label: Text(
                            _selectedImage == null
                                ? 'Seleccionar Comprobante'
                                : 'Cambiar Comprobante',
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: Styles.primaryColor),
                            foregroundColor: Styles.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitRequest,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Styles.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Enviar Solicitud',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Styles.primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan) {
    final isSelected = _selectedPlan?.id == plan.id;
    String durationText = 'Mensual';
    if (plan.duration == 'annual' || plan.duration == 'yearly') {
      durationText = 'Anual';
    } else if (plan.duration == 'semiannual') {
      durationText = 'Semestral';
    } else if (plan.duration == 'monthly') {
      durationText = 'Mensual';
    } else {
      durationText = plan.duration;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlan = plan;
          _selectedImage = null; // Reset image when changing plan
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFFFF8C00), Color(0xFFFF0080)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.workspace_premium,
              color: isSelected ? Colors.white : Styles.primaryColor,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.name.toUpperCase(),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Styles.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    durationText,
                    style: TextStyle(
                      color: isSelected ? Colors.white70 : Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${plan.currency} ',
                        style: TextStyle(
                          color: isSelected ? Colors.white70 : Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      TextSpan(
                        text: '${plan.price}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Styles.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Seleccionado',
                      style: TextStyle(
                        color: Styles.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
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
