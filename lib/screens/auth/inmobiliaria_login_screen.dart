import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/theme.dart';

class InmobiliariaLoginScreen extends StatefulWidget {
  const InmobiliariaLoginScreen({super.key});

  @override
  State<InmobiliariaLoginScreen> createState() => _InmobiliariaLoginScreenState();
}

class _InmobiliariaLoginScreenState extends State<InmobiliariaLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Login directo con FirebaseAuth para evitar conflictos con AuthService
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = userCredential.user;

      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        final role = userDoc.data()?['role'];
        
        // Permitir login solo si es empresa inmobiliaria
        if (userDoc.exists && role == 'inmobiliaria_empresa') {
          // Actualizar lastLogin
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'lastLogin': FieldValue.serverTimestamp()});
          
          if (mounted) {
            Modular.to.navigate('/inmobiliaria/home');
          }
        } else {
          await FirebaseAuth.instance.signOut();
          setState(() {
            _errorMessage = 'Esta cuenta no tiene acceso al portal inmobiliario';
          });
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found') {
          _errorMessage = 'No existe una cuenta con este correo';
        } else if (e.code == 'wrong-password') {
          _errorMessage = 'La contraseña es incorrecta';
        } else if (e.code == 'invalid-email') {
          _errorMessage = 'El formato del correo no es válido';
        } else if (e.code == 'user-disabled') {
          _errorMessage = 'Esta cuenta ha sido deshabilitada';
        } else if (e.code == 'network-request-failed') {
          _errorMessage = 'Sin conexión a internet. Verifica tu red';
        } else if (e.code == 'too-many-requests') {
          _errorMessage = 'Demasiados intentos. Intenta más tarde';
        } else {
          _errorMessage = 'No se pudo iniciar sesión. Intenta nuevamente';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ocurrió un error inesperado. Intenta nuevamente';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          Modular.to.navigate('/login');
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Styles.textPrimary),
            onPressed: () => Modular.to.navigate('/login'),
          ),
        ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: Styles.spacingLarge,
            vertical: Styles.spacingXLarge,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: Styles.spacingXLarge),
                Center(
                  child: Icon(
                    Icons.business,
                    size: 80,
                    color: Styles.primaryColor,
                  ),
                ),
                SizedBox(height: Styles.spacingLarge),
                Text(
                  'Portal Inmobiliaria',
                  style: TextStyles.title.copyWith(
                    fontSize: 28,
                    color: Styles.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: Styles.spacingSmall),
                Text(
                  'Acceso exclusivo para empresas',
                  style: TextStyles.body.copyWith(
                    color: Styles.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: Styles.spacingXLarge * 1.5),
                Text(
                  'Correo Empresarial',
                  style: TextStyles.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Styles.textPrimary,
                  ),
                ),
                SizedBox(height: Styles.spacingSmall),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'El correo es requerido';
                    }
                    if (!value.contains('@')) {
                      return 'Ingrese un correo válido';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'empresa@ejemplo.com',
                    hintStyle: const TextStyle(
                      color: Color(0xFFD9D9D9),
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: Colors.white,
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
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: Styles.spacingMedium,
                      vertical: Styles.spacingMedium,
                    ),
                  ),
                ),
                SizedBox(height: Styles.spacingLarge),
                Text(
                  'Contraseña',
                  style: TextStyles.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Styles.textPrimary,
                  ),
                ),
                SizedBox(height: Styles.spacingSmall),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'La contraseña es requerida';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    hintStyle: const TextStyle(
                      color: Color(0xFFD9D9D9),
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: Colors.white,
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
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: Styles.spacingMedium,
                      vertical: Styles.spacingMedium,
                    ),
                  ),
                ),
                if (_errorMessage != null)
                  Padding(
                    padding: EdgeInsets.only(top: Styles.spacingMedium),
                    child: Text(
                      _errorMessage!,
                      style: TextStyles.caption.copyWith(
                        color: Styles.errorColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                SizedBox(height: Styles.spacingXLarge),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Styles.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Iniciar Sesión', style: TextStyle(fontSize: 16)),
                  ),
                ),
                SizedBox(height: Styles.spacingLarge),
                Center(
                  child: GestureDetector(
                    onTap: () => Modular.to.navigate('/inmobiliaria-register'),
                    child: Text(
                      '¿No tienes cuenta? Registra tu empresa',
                      style: TextStyles.body.copyWith(
                        color: Styles.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: Styles.spacingMedium),
                Center(
                  child: GestureDetector(
                    onTap: () => Modular.to.navigate('/login'),
                    child: Text(
                      'Volver al login principal',
                      style: TextStyles.body.copyWith(
                        color: Styles.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}
