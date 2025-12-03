// filepath: lib/providers/auth_provider.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- ESTADOS ---
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isAuthReady = false;
  // Rol por defecto. Usamos 'indefinido' para forzar la selección.
  String _userRole = 'indefinido';
  // Estado premium del usuario
  bool _isPremium = false;

  // --- GETTERS ---
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  User? get currentUser => _auth.currentUser;
  bool get isAuthReady => _isAuthReady;
  String get userRole => _userRole;
  bool get isPremium => _isPremium;

  // --- CONSTANTE DEL ROL DE SELECCIÓN PENDIENTE ---
  static const String ROLE_PENDING = 'indefinido';

  // --- CONSTRUCTOR: ESCUCHA DE SESIÓN ---
  AuthService() {
    // Escucha cambios de sesión de Firebase
    _auth.authStateChanges().listen((User? user) async {
      _isAuthenticated = (user != null);
      _isLoading = false;
      _isAuthReady = true;
      if (user != null) {
        await _fetchUserRole(user.uid);
      } else {
        _userRole = ROLE_PENDING;
      }
      notifyListeners();
    });
  }

  // --- FUNCIÓN HELPER: FUERZA EL ROL A 'indefinido' EN FIRESTORE ---
  Future<void> _resetRoleToIndefinido(User user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'role': ROLE_PENDING,
        'status': ROLE_PENDING,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) print("Error al resetear rol a indefinido: $e");
    }
  }

  // --- FUNCIÓN CENTRAL: ACTUALIZAR ROL (USADO EN RoleSelectionScreen) ---
  Future<void> updateUserRole(String newRole) async {
    final user = currentUser;
    if (user == null) {
      _errorMessage = 'Usuario no autenticado para actualizar el rol.';
      throw Exception(_errorMessage);
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'role': newRole,
        'status': newRole,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _userRole = newRole;
    } catch (e) {
      _errorMessage = 'Error al actualizar el rol en Firestore: $e';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- FUNCIÓN PARA RESETEAR ROL (Para botón "Regresar") ---
  Future<void> resetRole() async {
    final user = currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _resetRoleToIndefinido(user);
      _userRole = ROLE_PENDING;
    } catch (e) {
      _errorMessage = 'Error al resetear rol: $e';
      if (kDebugMode) print("Error resetRole: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- FUNCIÓN DE EDICIÓN DE PERFIL (SOLICITADA) ---
  Future<bool> updateUserProfile({
    String? name,
    String? phone,
    String? photoUrl,
  }) async {
    final user = currentUser;
    if (user == null) {
      _errorMessage = 'Usuario no autenticado para actualizar el perfil.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Actualizar campos en Firebase Auth
      if (name != null) await user.updateDisplayName(name);
      if (photoUrl != null) await user.updatePhotoURL(photoUrl);

      await user.reload(); // Recargar el objeto User

      // 2. Preparar datos para Firestore
      Map<String, dynamic> updateData = {
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) updateData['displayName'] = name;
      if (phone != null) updateData['phoneNumber'] = phone;
      if (photoUrl != null) updateData['photoURL'] = photoUrl;

      // 3. Actualizar campos en Firestore
      await _firestore.collection('users').doc(user.uid).update(updateData);

      return true;
    } catch (e) {
      _errorMessage = 'Error al actualizar el perfil: $e';
      if (kDebugMode) print("Error en updateUserProfile: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- OTRAS FUNCIONES HELPER ---

  Future<void> _fetchUserRole(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      // Si el rol ya está en la DB, lo usamos. Si no, o si está 'indefinido', usamos ROLE_PENDING.
      _userRole = doc.data()?['role'] ?? ROLE_PENDING;
      
      // Verificar estado premium desde premium_users collection
      if (_userRole == 'inmobiliaria_empresa') {
        final premiumDoc = await _firestore.collection('premium_users').doc(uid).get();
        _isPremium = premiumDoc.exists && premiumDoc.data()?['status'] == 'active';
      } else {
        _isPremium = doc.data()?['isPremium'] ?? false;
      }
    } catch (e) {
      if (kDebugMode) print("Error fetching user role: $e");
      _userRole = ROLE_PENDING;
      _isPremium = false;
    }
  }

  // --- REGISTRO EMAIL ---
  Future<User?> registerWithEmailPassword({
    required String email,
    required String password,
    required String displayName,
    required String phone,
    required String userRole,
    String? photoUrl,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;

      if (user != null) {
        await user.updateDisplayName(displayName);
        if (photoUrl != null) await user.updatePhotoURL(photoUrl);
        await user.reload();
        user = _auth.currentUser;

        // GUARDAR EN FIRESTORE
        try {
          await _saveUserToFirestore(
            user!,
            extraData: {
              'phoneNumber': phone,
              'displayName': displayName,
              'role': ROLE_PENDING, // Siempre 'indefinido' al registrar
              'status': ROLE_PENDING,
              if (photoUrl != null) 'photoURL': photoUrl,
            },
          );
          _userRole = ROLE_PENDING;
        } catch (e) {
          if (kDebugMode)
            print("ADVERTENCIA: Falló Firestore al registrar: $e");
        }
      }
      return user;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapFirebaseError(e.code);
      return null;
    } catch (e) {
      _errorMessage = 'Error desconocido: $e';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- LOGIN EMAIL ---
  Future<User?> signInWithEmailPassword(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;

      if (user != null) {
        await user.reload();
        user = _auth.currentUser;

        try {
          await _saveUserToFirestore(user!);
          await _fetchUserRole(user.uid);
        } catch (e) {
          if (kDebugMode)
            print("ADVERTENCIA: Falló Firestore al iniciar sesión: $e");
        }
      }
      return user;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapFirebaseError(e.code);
      return null;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- LOGIN GOOGLE ---
  Future<User?> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential result = await _auth.signInWithCredential(
        credential,
      );

      User? user = result.user;

      if (user != null) {
        await user.reload();
        user = _auth.currentUser;

        try {
          await _saveUserToFirestore(user!);
          await _fetchUserRole(user.uid);
        } catch (e) {
          if (kDebugMode)
            print("ADVERTENCIA: Falló Firestore con Google Login: $e");
        }
      }

      return user;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapFirebaseError(e.code);
      return null;
    } catch (e) {
      _errorMessage = 'Error con Google Sign-In: $e';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- LOGOUT ---
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // --- FIRESTORE HELPER: CREAR/ACTUALIZAR USUARIO ---
  Future<void> _saveUserToFirestore(
    User user, {
    Map<String, dynamic>? extraData,
  }) async {
    try {
      final docRef = _firestore.collection('users').doc(user.uid);
      final docSnapshot = await docRef.get();

      final isNewUser = !docSnapshot.exists;

      final data = {
        'uid': user.uid,
        'email': user.email,
        'photoURL': user.photoURL,
        'lastLogin': FieldValue.serverTimestamp(),
        'displayName': user.displayName,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (isNewUser) {
        data['role'] = extraData?['role'] ?? ROLE_PENDING;
        data['status'] = extraData?['status'] ?? ROLE_PENDING;
        data['createdAt'] = FieldValue.serverTimestamp();
      }

      if (extraData != null) {
        data.addAll(extraData);
      }

      await docRef.set(data, SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'El correo ya está registrado.';
      case 'user-not-found':
        return 'Usuario no encontrado.';
      case 'wrong-password':
        return 'Contraseña incorrecta.';
      case 'invalid-email':
        return 'Correo inválido.';
      case 'weak-password':
        return 'Contraseña muy débil (mínimo 6 caracteres).';
      case 'network-request-failed':
        return 'Error de red. Verifique su conexión.';
      default:
        return 'Error de autenticación ($code).';
    }
  }
}
