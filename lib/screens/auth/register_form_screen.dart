// filepath: lib/screens/auth/register_form_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/theme.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../services/image_service.dart';

class RegisterFormScreen extends StatefulWidget {
  final String userType;
  final User? prefilledUser;
  const RegisterFormScreen({
    super.key,
    required this.userType,
    this.prefilledUser,
  });

  @override
  State<RegisterFormScreen> createState() => _RegisterFormScreenState();
}

class _RegisterFormScreenState extends State<RegisterFormScreen> {
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();

  // Controladores
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _smsCodeController = TextEditingController();
  final TextEditingController _birthdateController = TextEditingController();
  DateTime? _selectedBirthdate;

  // Estado del flujo
  int _currentStep = 0;
  bool _acceptedTerms = false;
  bool _isLoading = false;

  // Estado Verificación SMS con Firebase Auth
  bool _codeSent = false;
  bool _isPhoneVerified = false;
  bool _isGoogleLinking = false;
  String _verificationId = '';
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Estado Foto y ML Kit
  File? _profileImage;
  bool _isFaceDetected = false;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableClassification: true, // Para ojos abiertos/cerrados si se desea
    ),
  );

  // Servicio de Auth
  final app_auth.AuthService _authService = Modular.get<app_auth.AuthService>();

  @override
  void initState() {
    super.initState();
    if (widget.prefilledUser != null) {
      _nameController.text = widget.prefilledUser!.displayName ?? '';
      if (widget.prefilledUser!.phoneNumber != null &&
          widget.prefilledUser!.phoneNumber!.isNotEmpty) {
        _phoneController.text = widget.prefilledUser!.phoneNumber!.replaceAll(
          '+591',
          '',
        );
        _isPhoneVerified = true;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _smsCodeController.dispose();
    _birthdateController.dispose();
    _faceDetector.close();
    super.dispose();
  }

  // --- Lógica de Pasos ---

  void _nextStep() {
    if (_currentStep == 0) {
      if (_formKeyStep1.currentState!.validate()) {
        if (!_acceptedTerms) {
          _showSnackBar(
            'Debes aceptar los términos y condiciones',
            isError: true,
          );
          return;
        }
        setState(() => _currentStep = 1);
      }
    } else if (_currentStep == 1) {
      // Step 2 is now either Google link or Phone verify
      if (_isPhoneVerified || widget.prefilledUser != null) {
        setState(() => _currentStep = 2);
      } else {
        _showSnackBar(
          'Debes vincular tu cuenta o verificar tu teléfono',
          isError: true,
        );
      }
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Modular.to.navigate('/login');
    }
  }

  // --- Lógica WhatsApp (Twilio) ---

  Future<void> _verifyPhone() async {
    if (!_formKeyStep2.currentState!.validate()) return;

    final phoneText = _phoneController.text.trim();

    // Validar que el número tenga 8 dígitos y empiece con 6 o 7
    if (phoneText.length != 8) {
      _showSnackBar(
        'El número debe tener exactamente 8 dígitos',
        isError: true,
      );
      return;
    }

    if (!phoneText.startsWith('6') && !phoneText.startsWith('7')) {
      _showSnackBar('El número debe empezar con 6 o 7', isError: true);
      return;
    }

    final phone = '+591$phoneText';

    // Verificar si el número ya está registrado
    final isRegistered = await _authService.isPhoneNumberRegistered(phone);
    if (isRegistered) {
      _showSnackBar(
        'Este número ya está registrado. Usa otro número o inicia sesión.',
        isError: true,
      );
      return;
    }

    // Confirmación antes de enviar para no desperdiciar intentos
    final shouldSend = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar número'),
        content: Text(
          '¿Enviar código de verificación a:\n\n+591 $phoneText?\n\nAsegúrate de que el número sea correcto.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Styles.primaryColor,
            ),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );

    if (shouldSend != true) return;

    setState(() => _isLoading = true);

    print('📱 [REGISTRO] Iniciando verificación Firebase Auth para: $phone');

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          print('✅ [REGISTRO] Verificación automática completada');
          setState(() {
            _isPhoneVerified = true;
            _codeSent = true;
            _isLoading = false;
          });
          _showSnackBar('Teléfono verificado automáticamente', isError: false);
        },
        verificationFailed: (FirebaseAuthException e) {
          print('❌ [REGISTRO] Error: ${e.code} - ${e.message}');
          setState(() => _isLoading = false);

          String message =
              'Error: ${e.message ?? "No se pudo enviar el código"}';
          if (e.code == 'too-many-requests' ||
              e.message?.contains('39') == true) {
            message =
                'Tu número no está disponible para registrarse por SMS. Por favor, usa Google para crear tu cuenta.';
          }

          _showSnackBar(message, isError: true);
        },
        codeSent: (String verificationId, int? resendToken) {
          print('✅ [REGISTRO] Código enviado, verificationId: $verificationId');
          setState(() {
            _verificationId = verificationId;
            _codeSent = true;
            _isLoading = false;
          });
          _showSnackBar(
            'Código SMS enviado. Revisa tus mensajes.',
            isError: false,
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print('⏱️ [REGISTRO] Timeout de auto-retrieval');
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      print('❌ [REGISTRO] Excepción: $e');
      setState(() => _isLoading = false);
      _showSnackBar('Error inesperado: $e', isError: true);
    }
  }

  Future<void> _submitSmsCode() async {
    if (_smsCodeController.text.length < 6) {
      _showSnackBar('Ingresa el código de 6 dígitos', isError: true);
      return;
    }

    if (_verificationId.isEmpty) {
      _showSnackBar(
        'Error: No se ha enviado código de verificación',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    final code = _smsCodeController.text.trim();
    print('🔐 [REGISTRO] Verificando código: $code');

    try {
      // Crear credencial con el código SMS
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: code,
      );

      // Verificar la credencial (esto no crea una cuenta, solo valida el número)
      await _auth.signInWithCredential(credential);

      print('✅ [REGISTRO] Código verificado correctamente');
      setState(() => _isLoading = false);
      await _finalizePhoneVerification();
    } on FirebaseAuthException catch (e) {
      print('❌ [REGISTRO] Error Firebase: ${e.code} - ${e.message}');
      setState(() => _isLoading = false);

      String errorMsg = 'Código inválido o expirado';
      if (e.code == 'invalid-verification-code') {
        errorMsg = 'Código incorrecto';
      } else if (e.code == 'session-expired') {
        errorMsg = 'El código ha expirado. Solicita uno nuevo';
      }

      _showSnackBar(errorMsg, isError: true);
    } catch (e) {
      print('❌ [REGISTRO] Excepción: $e');
      setState(() => _isLoading = false);
      _showSnackBar('Error inesperado: $e', isError: true);
    }
  }

  Future<void> _finalizePhoneVerification() async {
    // Cerrar sesión de Firebase Auth (solo usamos para verificar, no para crear cuenta)
    await _auth.signOut();

    setState(() {
      _isPhoneVerified = true;
      _isLoading = false;
    });
    _showSnackBar('¡Teléfono verificado correctamente!', isError: false);
    // Opcional: Avanzar automáticamente
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _currentStep = 2);
    });
  }

  // --- Lógica Foto y ML Kit ---

  Future<void> _takePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera, // OBLIGATORIO CÁMARA
        maxWidth: 1000,
        maxHeight: 1000,
        preferredCameraDevice: CameraDevice.front,
      );

      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
          _isLoading = true;
        });
        await _processImage(InputImage.fromFilePath(image.path));
      }
    } catch (e) {
      _showSnackBar('Error al tomar foto: $e', isError: true);
    }
  }

  Future<void> _processImage(InputImage inputImage) async {
    try {
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      setState(() {
        _isLoading = false;
        if (faces.isNotEmpty) {
          // Validaciones extra opcionales:
          // final face = faces.first;
          // if (face.leftEyeOpenProbability != null && face.leftEyeOpenProbability! < 0.5) ...

          _isFaceDetected = true;
          _showSnackBar('Rostro detectado correctamente', isError: false);
        } else {
          _isFaceDetected = false;
          _profileImage = null; // Rechazar foto
          _showSnackBar(
            'No se detectó un rostro claro. Intenta de nuevo.',
            isError: true,
          );
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isFaceDetected = false;
        _profileImage = null;
      });
      _showSnackBar('Error al procesar imagen: $e', isError: true);
    }
  }

  Future<void> _handleFinalRegister() async {
    if (!_isFaceDetected || _profileImage == null) {
      _showSnackBar('Debes tomar una foto válida con tu rostro', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      _showSnackBar(
        'Sesión expirada. Por favor, inicia sesión de nuevo.',
        isError: true,
      );
      Modular.to.navigate('/login');
      return;
    }

    final phoneWithPrefix = '+591${_phoneController.text.trim()}';

    try {
      // 1. Subir foto
      final photoUrl = await ImageService.uploadAvatarToApi(
        XFile(_profileImage!.path),
        userId: currentUser.uid,
      );

      // 2. Guardar en Firestore (YA NO creamos cuenta auth, el user ya existe en Firebase Auth)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .set({
            'uid': currentUser.uid,
            'email': currentUser.email,
            'displayName': _nameController.text.trim(),
            'phoneNumber': phoneWithPrefix,
            'birthdate': _selectedBirthdate != null
                ? Timestamp.fromDate(_selectedBirthdate!)
                : null,
            'photoURL': photoUrl,
            'role': widget.userType,
            'status': widget.userType,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'lastLogin': FieldValue.serverTimestamp(),
            'isActive': true,
            'phoneVerified': _isPhoneVerified, // Usar el estado real
            'photoVerified': true,
            'authMethod':
                currentUser.providerData.any(
                  (p) => p.providerId == 'google.com',
                )
                ? 'google'
                : 'phone',
          }, SetOptions(merge: true));

      // 3. Opcional: Actualizar perfil de Firebase Auth
      await currentUser.updateDisplayName(_nameController.text.trim());
      await currentUser.updatePhotoURL(photoUrl);

      if (mounted) {
        _showSnackBar('¡Registro completado con éxito!', isError: false);
        Modular.to.navigate('/select-role');
      }
    } catch (e) {
      print('Error en registro final: $e');
      if (mounted) {
        _showSnackBar('Error al completar registro: $e', isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleLinkFallback() async {
    setState(() {
      _isLoading = true;
      _isGoogleLinking = true;
    });

    try {
      final user = await _authService.signInWithGoogle();
      if (user != null) {
        setState(() {
          _isPhoneVerified = true;
        });
        _showSnackBar('Cuenta Google vinculada correctamente');
        // El usuario ya puede dar a "Continuar"
      }
    } catch (e) {
      _showSnackBar('Error al vincular con Google: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
        _isGoogleLinking = false;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Styles.errorColor : Styles.successColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Styles.textPrimary),
          onPressed: _prevStep,
        ),
        title: Column(
          children: [
            Text(
              'Crear Cuenta',
              style: TextStyles.subtitle.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              'Paso ${_currentStep + 1} de 3',
              style: TextStyles.caption.copyWith(color: Styles.textSecondary),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Indicador de progreso lineal
            LinearProgressIndicator(
              value: (_currentStep + 1) / 3,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(Styles.primaryColor),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: _buildCurrentStep(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Data();
      case 1:
        return _buildStep2Phone();
      case 2:
        return _buildStep3Photo();
      default:
        return const SizedBox.shrink();
    }
  }

  // PASO 1: Datos Personales
  Widget _buildStep1Data() {
    return Form(
      key: _formKeyStep1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Datos Personales',
            style: TextStyles.title.copyWith(fontSize: 22),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Ingresa tu información básica para comenzar.',
            style: TextStyles.body.copyWith(color: Styles.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          _buildLabel('Nombre completo'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameController,
            decoration: _buildInputDecoration(hintText: 'Ej: Juan Pérez'),
            validator: (v) =>
                (v?.length ?? 0) < 5 ? 'Mínimo 5 caracteres' : null,
          ),
          const SizedBox(height: 20),

          _buildLabel('Fecha de nacimiento'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _birthdateController,
            readOnly: true,
            decoration: _buildInputDecoration(
              hintText: 'Selecciona tu fecha de nacimiento',
              suffixIcon: const Icon(Icons.calendar_today),
            ),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime(2000),
                firstDate: DateTime(1940),
                lastDate: DateTime.now().subtract(
                  const Duration(days: 365 * 13),
                ),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.light(
                        primary: Styles.primaryColor,
                        onPrimary: Colors.white,
                        onSurface: Styles.textPrimary,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (date != null) {
                setState(() {
                  _selectedBirthdate = date;
                  _birthdateController.text =
                      '${date.day}/${date.month}/${date.year}';
                });
              }
            },
            validator: (v) => _selectedBirthdate == null
                ? 'Selecciona tu fecha de nacimiento'
                : null,
          ),
          const SizedBox(height: 24),

          // Términos
          Row(
            children: [
              Checkbox(
                value: _acceptedTerms,
                activeColor: Styles.primaryColor,
                onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final url = Uri.parse(
                      'https://sites.google.com/view/comercialapp',
                    );
                    if (await canLaunchUrl(url)) {
                      await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  child: Text.rich(
                    TextSpan(
                      text: 'Acepto los ',
                      style: TextStyles.caption,
                      children: [
                        TextSpan(
                          text: 'términos y condiciones',
                          style: TextStyles.caption.copyWith(
                            color: Styles.primaryColor,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _nextStep,
            style: _primaryButtonStyle(),
            child: const Text('Siguiente'),
          ),
        ],
      ),
    );
  }

  // PASO 2: Verificación Teléfono / Google
  Widget _buildStep2Phone() {
    final isGoogleFunnel = widget.prefilledUser != null;

    return Form(
      key: _formKeyStep2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            isGoogleFunnel ? Icons.link_rounded : Icons.sms,
            size: 60,
            color: Styles.primaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            isGoogleFunnel ? 'Vincular con Google' : 'Verificación por SMS',
            style: TextStyles.title.copyWith(fontSize: 22),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isGoogleFunnel
                ? 'Tu cuenta de Google ya está vinculada. Ahora ingresa un teléfono de referencia.'
                : 'Te enviaremos un código por SMS para verificar tu número de teléfono.',
            style: TextStyles.body.copyWith(color: Styles.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          if (isGoogleFunnel) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Cuenta Google: ${widget.prefilledUser!.email}',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          _buildLabel('Número de celular'),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: const Text(
                  '+591',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  enabled: !_isPhoneVerified,
                  maxLength: 8,
                  onChanged: (v) => setState(() {}),
                  decoration: _buildInputDecoration(
                    hintText: '70123456',
                  ).copyWith(counterText: ''),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Ingresa tu número';
                    if (v.length != 8) return 'Debe tener 8 dígitos';
                    return null;
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          if (isGoogleFunnel) ...[
            ElevatedButton(
              onPressed: _phoneController.text.length >= 8 ? _nextStep : null,
              style: _primaryButtonStyle(),
              child: const Text('Confirmar y Siguiente'),
            ),
          ] else if (!_isPhoneVerified) ...[
            // Si el SMS no llega o falla, permitir Google como respaldo
            Column(
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyPhone,
                  style: _primaryButtonStyle(),
                  child: _isLoading && !_isGoogleLinking
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_codeSent ? 'Reenviar Código' : 'Enviar Código'),
                ),
                const SizedBox(height: 16),
                const Text('o', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _handleGoogleLinkFallback,
                  icon: const Icon(Icons.login),
                  label: const Text('Vincular con Google (Respaldo)'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 50),
                    side: const BorderSide(color: Styles.primaryColor),
                  ),
                ),
                if (_codeSent) ...[
                  const SizedBox(height: 24),
                  _buildLabel('Código de verificación'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _smsCodeController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, letterSpacing: 8),
                    maxLength: 6,
                    decoration: _buildInputDecoration(hintText: '000000'),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitSmsCode,
                    style: _primaryButtonStyle(),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Verificar Código'),
                  ),
                ],
              ],
            ),
          ] else if (_isPhoneVerified) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: Row(
                children: const [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 12),
                  Text(
                    'Teléfono verificado',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _nextStep,
              style: _primaryButtonStyle(),
              child: const Text('Continuar'),
            ),
          ],
        ],
      ),
    );
  }

  // PASO 3: Foto Obligatoria
  Widget _buildStep3Photo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.face_retouching_natural,
          size: 60,
          color: Styles.primaryColor,
        ),
        const SizedBox(height: 16),
        Text(
          'Foto de Perfil',
          style: TextStyles.title.copyWith(fontSize: 22),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Por seguridad, necesitamos una foto real tuya. Usaremos inteligencia artificial para validarla.',
          style: TextStyles.body.copyWith(color: Styles.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        Center(
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
              border: Border.all(
                color: _isFaceDetected
                    ? Colors.green
                    : (_profileImage != null ? Colors.red : Colors.grey[300]!),
                width: 4,
              ),
              image: _profileImage != null
                  ? DecorationImage(
                      image: FileImage(_profileImage!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _profileImage == null
                ? Icon(Icons.camera_alt, size: 60, color: Colors.grey[400])
                : null,
          ),
        ),

        const SizedBox(height: 16),

        if (_profileImage != null)
          Center(
            child: Chip(
              avatar: Icon(
                _isFaceDetected ? Icons.check : Icons.error,
                color: Colors.white,
                size: 18,
              ),
              label: Text(
                _isFaceDetected ? 'Rostro Detectado' : 'Rostro NO Detectado',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: _isFaceDetected ? Colors.green : Colors.red,
            ),
          ),

        const SizedBox(height: 32),

        if (!_isFaceDetected)
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _takePhoto,
            icon: const Icon(Icons.camera_alt),
            label: Text(
              _profileImage == null ? 'Tomar Foto' : 'Intentar de Nuevo',
            ),
            style: _primaryButtonStyle(),
          ),

        if (_isFaceDetected)
          ElevatedButton(
            onPressed: _isLoading ? null : _handleFinalRegister,
            style: _primaryButtonStyle(),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Finalizar Registro'),
          ),

        if (_isLoading && _isFaceDetected)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text('Creando cuenta...', textAlign: TextAlign.center),
          ),
      ],
    );
  }

  // --- Helpers UI ---

  Widget _buildLabel(String text) => Text(
    text,
    style: TextStyles.body.copyWith(
      fontWeight: FontWeight.w500,
      color: Styles.textPrimary,
    ),
  );

  InputDecoration _buildInputDecoration({
    required String hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFFD9D9D9), fontSize: 14),
      filled: true,
      fillColor: Colors.white,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  ButtonStyle _primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: Styles.primaryColor,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }
}
