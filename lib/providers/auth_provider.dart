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

  // --- CACHE DE DATOS DE USUARIO (OPTIMIZACIÓN DE VELOCIDAD) ---
  String?
  _userRole; // Guardamos el rol aquí para no pedirlo siempre a Firestore

  // --- GETTERS ---
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  User? get currentUser => _auth.currentUser;
  bool get isAuthReady => _isAuthReady;
  String? get userRole => _userRole; // Getter para el router

  // --- CONSTRUCTOR ---
  AuthService() {
    _auth.authStateChanges().listen((User? user) {
      _isAuthenticated = (user != null);
      if (user != null) {
        // Si hay usuario, cargamos su rol inmediatamente en memoria
        _fetchUserRole(user.uid);
      } else {
        _userRole = null;
        _isLoading = false;
        _isAuthReady = true;
        notifyListeners();
      }
    });
  }

  // --- CARGAR ROL EN MEMORIA (OPTIMIZACIÓN) ---
  Future<void> _fetchUserRole(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _userRole = doc.data()?['role'] ?? 'cliente';
      } else {
        _userRole = 'cliente';
      }
    } catch (e) {
      print("Error cargando rol: $e");
      _userRole = 'cliente';
    } finally {
      _isLoading = false;
      _isAuthReady = true;
      notifyListeners(); // Notificamos al Router que ya tenemos el rol
    }
  }

  // --- ACTUALIZAR ROL ---
  Future<void> updateUserRole(String newRole) async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = _auth.currentUser;
      if (user != null) {
        // 1. Actualizar en Firestore
        await _firestore.collection('users').doc(user.uid).update({
          'role': newRole,
          'status': newRole,
        });

        // 2. Actualizar estado local
        _userRole = newRole;

        // 3. Notificar a los listeners (Router)
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
      print("Error updating role: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- ACTUALIZAR PERFIL ---
  Future<bool> updateUserProfile({
    required String name,
    required String phone,
    String? photoUrl,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await user.updateDisplayName(name);
        if (photoUrl != null) await user.updatePhotoURL(photoUrl);

        Map<String, dynamic> updateData = {
          'displayName': name,
          'phoneNumber': phone,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (photoUrl != null) updateData['photoURL'] = photoUrl;

        await _firestore.collection('users').doc(user.uid).update(updateData);
        await user.reload();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- REGISTRO ---
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

        // Establecer rol localmente para evitar esperas
        _userRole = userRole;

        // Guardar en Firestore
        await _saveUserToFirestore(
          user!,
          extraData: {
            'phoneNumber': phone,
            'displayName': displayName,
            'role': userRole,
            'status': userRole,
            if (photoUrl != null) 'photoURL': photoUrl,
          },
        );
      }
      return user;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapFirebaseError(e.code);
      return null;
    } catch (e) {
      _errorMessage = 'Error desconocido: $e';
      return null;
    } finally {
      if (_auth.currentUser == null) {
        _isLoading = false;
        notifyListeners();
      }
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

      if (result.user != null) {
        await _saveUserToFirestore(result.user!);
        // Forzamos la carga del rol inmediatamente después del login
        await _fetchUserRole(result.user!.uid);
      }
      return result.user;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapFirebaseError(e.code);
      _isLoading = false;
      notifyListeners();
      rethrow;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
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
        _isLoading = false;
        notifyListeners();
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
      if (result.user != null) {
        await _saveUserToFirestore(result.user!);
        await _fetchUserRole(result.user!.uid);
      }

      return result.user;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // --- LOGOUT ---
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    // Resetear el rol a 'cliente' en Firestore antes de hacer logout
    // Esto asegura que cuando el usuario vuelva a iniciar sesión,
    // siempre vea la pantalla de selección de rol
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .update({'role': 'cliente', 'status': 'cliente'});
      } catch (e) {
        // Si hay error al actualizar Firestore, continuar con el logout
        print('Error resetting role on logout: $e');
      }
    }

    await _googleSignIn.signOut();
    await _auth.signOut();
    _userRole = null; // Limpiar rol al salir
  }

  // --- FIRESTORE HELPER ---
  Future<void> _saveUserToFirestore(
    User user, {
    Map<String, dynamic>? extraData,
  }) async {
    try {
      final data = {
        'uid': user.uid,
        'email': user.email,
        'photoURL': user.photoURL,
        'lastLogin': FieldValue.serverTimestamp(),
        'displayName': user.displayName,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (extraData != null) {
        data.addAll(extraData);
        data['createdAt'] = FieldValue.serverTimestamp();
      }

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) print("Error guardando usuario en Firestore: $e");
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
      default:
        return 'Error de autenticación ($code).';
    }
  }
}
