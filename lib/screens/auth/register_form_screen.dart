// filepath: lib/screens/auth/register_form_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../theme/theme.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../services/image_service.dart';
import '../../services/twilio_service.dart';

class RegisterFormScreen extends StatefulWidget {
  final String userType;
  const RegisterFormScreen({super.key, required this.userType});

  @override
  State<RegisterFormScreen> createState() => _RegisterFormScreenState();
}

class _RegisterFormScreenState extends State<RegisterFormScreen> {
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();

  // Controladores
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _smsCodeController = TextEditingController();

  // Estado del flujo
  int _currentStep = 0;
  bool _acceptedTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  // Estado Verificación WhatsApp
  bool _codeSent = false;
  bool _isPhoneVerified = false;

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
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _phoneController.dispose();
    _smsCodeController.dispose();
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
      if (_isPhoneVerified) {
        setState(() => _currentStep = 2);
      } else {
        _showSnackBar('Debes verificar tu número de teléfono', isError: true);
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
    if (phoneText.length != 8 || (!phoneText.startsWith('6') && !phoneText.startsWith('7'))) {
      _showSnackBar('Ingresa un número válido (8 dígitos, debe empezar con 6 o 7)', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final phone = '+591$phoneText';
    print('📱 [REGISTRO] Iniciando verificación para: $phone');

    final success = await TwilioService.sendWhatsAppVerification(phone);

    setState(() => _isLoading = false);

    if (success) {
      print('✅ [REGISTRO] Código enviado exitosamente');
      setState(() => _codeSent = true);
      _showSnackBar('Código enviado por SMS', isError: false);
    } else {
      print('❌ [REGISTRO] Falló el envío del código');
      _showSnackBar('Error al enviar código. Verifica tu número', isError: true);
    }
  }

  void _showDialog(String title, String message, {VoidCallback? onConfirm}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          if (onConfirm != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onConfirm();
              },
              child: const Text('Continuar'),
            ),
        ],
      ),
    );
  }

  Future<void> _submitSmsCode() async {
    if (_smsCodeController.text.length < 6) {
      _showSnackBar('Ingresa el código de 6 dígitos', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final phone = '+591${_phoneController.text.trim()}';
    final code = _smsCodeController.text.trim();
    print('🔐 [REGISTRO] Verificando código: $code para $phone');

    final isValid = await TwilioService.verifyCode(phone, code);

    setState(() => _isLoading = false);

    if (isValid) {
      print('✅ [REGISTRO] Código verificado correctamente');
      await _finalizePhoneVerification();
    } else {
      print('❌ [REGISTRO] Código inválido o expirado');
      _showSnackBar('Código inválido o expirado', isError: true);
    }
  }

  Future<void> _finalizePhoneVerification() async {
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

  // --- Registro Final ---

  Future<void> _handleFinalRegister() async {
    if (!_isFaceDetected || _profileImage == null) {
      _showSnackBar('Debes tomar una foto válida con tu rostro', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    // 1. Subir imagen primero (necesitamos URL para el perfil)
    // Nota: Idealmente se sube después de crear el usuario para usar su UID en el path,
    // pero AuthService espera la URL o el File. AuthService maneja la subida si le pasamos el File?
    // Revisando AuthService... parece que no maneja subida de foto en registerWithEmailPassword.
    // Tendremos que modificar AuthService o subirla aquí después de crear el usuario.
    // ESTRATEGIA: Crear usuario -> Obtener UID -> Subir Foto -> Actualizar Perfil.

    // Usaremos el método existente registerWithEmailPassword
    // Y luego actualizaremos la foto.

    final user = await _authService.registerWithEmailPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      displayName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      userRole: 'cliente',
    );

    if (user != null) {
      try {
        // Subir foto
        final photoUrl = await ImageService.uploadAvatarToApi(
          XFile(_profileImage!.path),
          userId: user.uid,
        );

        // Actualizar usuario con foto y flag de verificado
        // Actualizar usuario con foto y flag de verificado
        await _authService.updateUserProfile(photoUrl: photoUrl);
        // Aquí podríamos guardar en Firestore que el teléfono y foto fueron verificados
        // Por ahora asumimos que si tiene foto, pasó el proceso.

        if (mounted) {
          _showSnackBar('¡Registro completado con éxito!', isError: false);
          Modular.to.navigate('/login');
        }
      } catch (e) {
        _showSnackBar(
          'Usuario creado, pero error al subir foto: $e',
          isError: true,
        );
        // Aún así navegamos al login o home
        Modular.to.navigate('/login');
      }
    } else {
      if (mounted) {
        _showSnackBar(
          _authService.errorMessage ?? 'Error al registrarse',
          isError: true,
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
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

          _buildLabel('Correo electrónico'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: _buildInputDecoration(hintText: 'ej: juan@email.com'),
            validator: (v) =>
                !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v ?? '')
                ? 'Correo inválido'
                : null,
          ),
          const SizedBox(height: 20),

          _buildLabel('Contraseña'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: _buildInputDecoration(
              hintText: '••••••••',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) =>
                (v?.length ?? 0) < 6 ? 'Mínimo 6 caracteres' : null,
          ),
          const SizedBox(height: 20),

          _buildLabel('Confirmar contraseña'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _confirmController,
            obscureText: _obscureConfirmPassword,
            decoration: _buildInputDecoration(
              hintText: '••••••••',
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
            ),
            validator: (v) => v != _passwordController.text
                ? 'Las contraseñas no coinciden'
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
                child: Text(
                  'Acepto los términos y condiciones',
                  style: TextStyles.caption,
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

  // PASO 2: Verificación Teléfono
  Widget _buildStep2Phone() {
    return Form(
      key: _formKeyStep2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FaIcon(
            FontAwesomeIcons.whatsapp,
            size: 60,
            color: Color(0xFF25D366),
          ),
          const SizedBox(height: 16),
          Text(
            'Verificación por WhatsApp',
            style: TextStyles.title.copyWith(fontSize: 22),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Te enviaremos un código por WhatsApp para verificar que eres tú.',
            style: TextStyles.body.copyWith(color: Styles.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

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
                  enabled: !_isPhoneVerified, // Bloquear si ya está verificado
                  decoration: _buildInputDecoration(hintText: '70123456'),
                  validator: (v) =>
                      (v?.length ?? 0) < 8 ? 'Número inválido' : null,
                ),
              ),
            ],
          ),

          if (!_codeSent && !_isPhoneVerified) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _verifyPhone,
              style: _primaryButtonStyle(),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Enviar Código WhatsApp'),
            ),
          ],

          if (_codeSent && !_isPhoneVerified) ...[
            const SizedBox(height: 32),
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
            TextButton(
              onPressed: _isLoading ? null : _verifyPhone, // Reenviar
              child: const Text('Reenviar código'),
            ),
          ],

          if (_isPhoneVerified) ...[
            const SizedBox(height: 32),
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
