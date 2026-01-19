// filepath: lib/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../providers/auth_provider.dart';
import '../../theme/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  final AuthService _authService = Modular.get<AuthService>();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  bool _codeSent = false;
  String? _errorMessage;
  String _verificationId = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _authService.addListener(_onAuthServiceChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _authService.removeListener(_onAuthServiceChanged);
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _onAuthServiceChanged() {
    if (mounted) setState(() {});
  }

  void _handleExistenceCheck(User user) async {
    // CHEQUEO DE EXISTENCIA: Forzar servidor para evitar caché persistente de perfiles borrados
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get(const GetOptions(source: Source.server));

    if (doc.exists) {
      final userData = doc.data();
      final role = userData?['role'] ?? 'indefinido';

      if (role == 'indefinido') {
        print(
          '🚀 [FUNNEL] Usuario con perfil incompleto, redirigiendo a registro...',
        );
        _redirectToRegister(user);
        return;
      }

      if (role == 'inmobiliaria_empresa') {
        await _authService.signOut();
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Esta es una cuenta de empresa. Usa el portal inmobiliario';
        });
        return;
      }
      Modular.to.navigate('/select-role');
    } else {
      // --- NUEVA LÓGICA ESTRICTA ---
      // Si es un usuario nuevo detectado en el LOGIN, no lo dejamos pasar.
      // Debe registrarse explícitamente por el botón de Registro.
      print(
        '🚀 [FUNNEL] Intento de login de usuario nuevo con Google. BLOQUEANDO.',
      );

      // 1. Cerrar sesión inmediatamente
      await _authService.signOut();

      // 2. Notificar al usuario
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'No tienes una cuenta creada. Por favor, ve a "Crear una cuenta nueva" primero.';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No tienes una cuenta. Por favor, regístrate primero.',
            ),
            backgroundColor: Styles.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _redirectToRegister(User user) {
    Modular.to.navigate(
      '/register-form',
      arguments: {'userType': 'cliente', 'prefilledUser': user},
    );
  }

  // --- Lógica de Google ---
  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _authService.signInWithGoogle();
      if (user != null && mounted) {
        // CHEQUEO DE EXISTENCIA: Forzar servidor para evitar caché persistente de perfiles borrados
        // This check is now integrated into _handleExistenceCheck
        _handleExistenceCheck(user);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al iniciar sesión con Google';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Lógica de Teléfono ---
  Future<void> _sendOTP() async {
    final phoneText = _phoneController.text.trim();
    if (phoneText.length < 8) {
      setState(() => _errorMessage = 'Número inválido');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final phone = '+591$phoneText';

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _signInWithPhoneCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _isLoading = false;
            if (e.code == 'too-many-requests' ||
                e.message?.contains('39') == true) {
              _errorMessage =
                  'Problemas con SMS en tu región. Por favor, usa Google.';
            } else {
              _errorMessage = 'Error: ${e.message}';
            }
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _codeSent = true;
            _isLoading = false;
          });
        },
        codeAutoRetrievalTimeout: (String vId) => _verificationId = vId,
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Hubo un problema al enviar el código.';
      });
    }
  }

  Future<void> _verifyOTP() async {
    if (_otpController.text.length < 6) {
      setState(() => _errorMessage = 'Ingresa el código de 6 dígitos');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: _otpController.text.trim(),
      );
      await _signInWithPhoneCredential(credential);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Código incorrecto o expirado.';
      });
    }
  }

  Future<void> _signInWithPhoneCredential(
    PhoneAuthCredential credential,
  ) async {
    try {
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null && mounted) {
        _handleExistenceCheck(user);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error al autenticar con el teléfono.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Image.asset(
                  'assets/images/logo_blue.png',
                  height: 100,
                  errorBuilder: (_, __, ___) =>
                      SvgPicture.asset('assets/images/Logo P2.svg', height: 60),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'Iniciar Sesión',
                textAlign: TextAlign.center,
                style: TextStyles.title.copyWith(
                  fontSize: 26,
                  color: Styles.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),

              // TABS UI
              TabBar(
                controller: _tabController,
                indicatorColor: Styles.primaryColor,
                labelColor: Styles.primaryColor,
                unselectedLabelColor: Colors.grey[400],
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: 'Con Google'),
                  Tab(text: 'Con Teléfono'),
                ],
              ),
              const SizedBox(height: 32),

              SizedBox(
                height: 280, // Adjusted height to accommodate content
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Google Tab
                    Column(
                      children: [
                        const SizedBox(height: 20),
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : _handleGoogleLogin,
                          icon: Image.asset(
                            'assets/images/google.png',
                            height: 24,
                          ),
                          label: const Text(
                            'Continuar con Google',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Styles.textPrimary,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 24,
                            ),
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Rápido, fácil y seguro con tu cuenta de Google.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),

                    // Phone Tab
                    Column(
                      children: [
                        if (!_codeSent) ...[
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFFE0E0E0),
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.grey[50],
                                ),
                                child: Row(
                                  children: [
                                    Image.asset(
                                      'assets/images/icon/bolivia_flag.png',
                                      width: 24,
                                      errorBuilder: (_, __, ___) =>
                                          const Text('🇧🇴'),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      '+591',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    hintText: 'Número de Teléfono',
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
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _sendOTP,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Styles.primaryColor,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : const Text(
                                      'Verificar Número',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ] else ...[
                          TextFormField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              letterSpacing: 8,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              hintText: '000000',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _verifyOTP,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Styles.primaryColor,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Confirmar Código',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() => _codeSent = false),
                            child: const Text('Cambiar número'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Styles.errorColor,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 32),
              Center(
                child: GestureDetector(
                  onTap: () => Modular.to.navigate(
                    '/register-form',
                    arguments: 'cliente',
                  ),
                  child: RichText(
                    text: TextSpan(
                      text: "¿No tienes una cuenta? ",
                      style: const TextStyle(color: Styles.textSecondary),
                      children: [
                        TextSpan(
                          text: 'Regístrate',
                          style: TextStyle(
                            color: Styles.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    Text(
                      '¿Eres una empresa o agente inmobiliario? ',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    GestureDetector(
                      onTap: () => Modular.to.navigate('/inmobiliaria-login'),
                      child: const Text(
                        'Ingresa aquí',
                        style: TextStyle(
                          color: Styles.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      ' o ',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    GestureDetector(
                      onTap: () =>
                          Modular.to.navigate('/inmobiliaria-register'),
                      child: const Text(
                        'Regístrate aquí',
                        style: TextStyle(
                          color: Styles.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
