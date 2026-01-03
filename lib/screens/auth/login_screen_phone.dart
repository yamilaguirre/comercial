// filepath: lib/screens/auth/login_screen_phone.dart
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../theme/theme.dart';

class LoginScreenPhone extends StatefulWidget {
  const LoginScreenPhone({super.key});

  @override
  State<LoginScreenPhone> createState() => _LoginScreenPhoneState();
}

class _LoginScreenPhoneState extends State<LoginScreenPhone> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  bool _codeSent = false;
  String _verificationId = '';
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final phone = '+591${_phoneController.text.trim()}';

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Error al enviar código: ${e.message}';
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _codeSent = true;
            _isLoading = false;
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
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
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: _otpController.text.trim(),
      );

      await _signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Código inválido o expirado';
      });
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null && mounted) {
        final phoneWithCode = '+591${_phoneController.text.trim()}';

        print(
          '🔍 [LOGIN] Usuario autenticado - UID: ${user.uid}, Phone: ${user.phoneNumber}',
        );

        // PASO 1: Buscar si ya existe un documento con este número de teléfono
        final existingUserQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('phoneNumber', isEqualTo: phoneWithCode)
            .limit(1)
            .get();

        bool isNewUser = true;
        Map<String, dynamic>? existingData;
        String? oldUid;

        if (existingUserQuery.docs.isNotEmpty) {
          // Ya existe un usuario con este número de teléfono
          final existingDoc = existingUserQuery.docs.first;
          oldUid = existingDoc.id;
          existingData = existingDoc.data();
          isNewUser = false;

          print(
            '⚠️ [LOGIN] Usuario existente encontrado con UID antiguo: $oldUid',
          );
          print('🔍 [LOGIN] UID nuevo de Auth: ${user.uid}');

          // Si el UID es diferente, actualizar el documento al nuevo UID
          if (oldUid != user.uid) {
            print('🔄 [LOGIN] Migrando documento de $oldUid a ${user.uid}...');

            // Copiar todos los datos al nuevo UID
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .set({
                  ...existingData,
                  'uid': user.uid, // Actualizar el UID
                  'lastLogin': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                  'phoneNumber': phoneWithCode,
                });

            // Migrar documento de premium_users si existe
            try {
              final premiumDoc = await FirebaseFirestore.instance
                  .collection('premium_users')
                  .doc(oldUid)
                  .get();

              if (premiumDoc.exists) {
                print(
                  '🔄 [LOGIN] Migrando premium_users de $oldUid a ${user.uid}...',
                );

                // Copiar documento premium al nuevo UID
                await FirebaseFirestore.instance
                    .collection('premium_users')
                    .doc(user.uid)
                    .set({
                      ...premiumDoc.data()!,
                      'userId': user.uid, // Actualizar el userId si existe
                      'updatedAt': FieldValue.serverTimestamp(),
                    });

                // Eliminar documento premium antiguo
                await FirebaseFirestore.instance
                    .collection('premium_users')
                    .doc(oldUid)
                    .delete();

                print('✅ [LOGIN] premium_users migrado exitosamente');
              }
            } catch (e) {
              print('⚠️ [LOGIN] Error migrando premium_users: $e');
            }

            // Eliminar el documento viejo de users
            try {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(oldUid)
                  .delete();
              print('✅ [LOGIN] Documento antiguo eliminado: $oldUid');
            } catch (e) {
              print('⚠️ [LOGIN] No se pudo eliminar documento antiguo: $e');
            }

            print('✅ [LOGIN] Migración completada a UID=${user.uid}');
          } else {
            // Mismo UID, solo actualizar
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .set({
                  'lastLogin': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                  'phoneNumber': phoneWithCode,
                }, SetOptions(merge: true));

            print('✅ [LOGIN] Documento ACTUALIZADO para UID=${user.uid}');
          }
        } else {
          // Usuario completamente nuevo
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
                'uid': user.uid,
                'phoneNumber': phoneWithCode,
                'role': 'indefinido',
                'status': 'indefinido',
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
                'lastLogin': FieldValue.serverTimestamp(),
                'isActive': true,
                'needsProfileCompletion': true,
              });

          print('✅ [LOGIN] Documento CREADO en Firestore para UID=${user.uid}');
        }

        final role = existingData?['role'] ?? 'indefinido';

        // Bloquear si es empresa inmobiliaria
        if (role == 'inmobiliaria_empresa') {
          await _auth.signOut();
          setState(() {
            _isLoading = false;
            _errorMessage =
                'Esta es una cuenta de empresa. Usa el portal inmobiliario';
          });
          return;
        }

        print('✅ Login exitoso: UID=${user.uid}, navegando a /select-role');

        // Si es un nuevo usuario, informarle que debe completar su perfil
        if (isNewUser && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '¡Bienvenido! Completa tu perfil después de seleccionar tu rol',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }

        // Login exitoso
        if (mounted) {
          Modular.to.navigate('/select-role');
        }
      }
    } catch (e) {
      print('❌ Error en _signInWithCredential: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error al iniciar sesión';
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Center(
                  child: SvgPicture.asset(
                    'assets/images/LogoColor.svg',
                    height: 70,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 48),
                Text(
                  'Iniciar Sesión',
                  style: TextStyles.title.copyWith(
                    fontSize: 28,
                    color: Styles.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),

                // Tabs
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          // Navegar a login con email
                          Modular.to.navigate('/login');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey[300]!,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            'Con Email',
                            textAlign: TextAlign.center,
                            style: TextStyles.body.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Styles.primaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Text(
                          'Con Teléfono',
                          textAlign: TextAlign.center,
                          style: TextStyles.body.copyWith(
                            color: Styles.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                if (!_codeSent) ...[
                  Text(
                    'Número de Teléfono',
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
                        child: Row(
                          children: [
                            Image.asset(
                              'assets/images/icon/bolivia_flag.png',
                              width: 24,
                              height: 24,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.red[100],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '🇧🇴',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            const Text('+591', style: TextStyle(fontSize: 16)),
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
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFE0E0E0),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFE0E0E0),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Styles.primaryColor,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Ingresa tu número';
                            }
                            if (value.length < 8) {
                              return 'Número inválido';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _sendOTP,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[400],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
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
                            'Verificar Número',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ] else ...[
                  Text(
                    'Ingresa el Código OTP',
                    style: TextStyles.body.copyWith(
                      fontWeight: FontWeight.w500,
                      color: Styles.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      hintText: '000000',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.white,
                      counterText: '',
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
                        borderSide: const BorderSide(
                          color: Styles.primaryColor,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _verifyOTP,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Styles.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
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
                            'Iniciar Sesión',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],

                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _errorMessage!,
                      style: TextStyles.caption.copyWith(
                        color: Styles.errorColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                const SizedBox(height: 24),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Modular.to.navigate(
                        '/register-form',
                        arguments: 'cliente',
                      );
                    },
                    child: RichText(
                      text: TextSpan(
                        text: "No tienes una cuenta? ",
                        style: TextStyles.body.copyWith(
                          color: Styles.textSecondary,
                        ),
                        children: [
                          TextSpan(
                            text: 'Regístrate',
                            style: TextStyles.body.copyWith(
                              color: Styles.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
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
