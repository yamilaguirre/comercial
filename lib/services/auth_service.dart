// services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_data_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserDataService _userDataService = UserDataService();

  // Stream del usuario actual
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Usuario actual
  User? get currentUser => _auth.currentUser;

  // Registro con email y password
  Future<User?> registerWithEmailPassword({
    required String email,
    required String password,
    required String displayName,
    required String phone,
    required String userRole,
  }) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final User? user = result.user;
      if (user != null) {
        // Actualizar perfil del usuario
        await user.updateDisplayName(displayName);
        
        // Guardar datos en Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': email,
          'display_name': displayName,
          'phone': phone,
          'user_role': userRole,
          'provider': 'email',
          'photo_url': '',
          'created_at': FieldValue.serverTimestamp(),
        });
        
        // Crear datos iniciales
        await _userDataService.createInitialUserData(user.uid);
      }
      
      return user;
    } catch (e) {
      print('Error registering user: $e');
      throw e;
    }
  }

  // Login con email y password
  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      print('Error signing in: $e');
      throw e;
    }
  }

  // Login con Google
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential result = await _auth.signInWithCredential(credential);
      final User? user = result.user;

      if (user != null) {
        // Crear o actualizar usuario en Firestore
        await _createOrUpdateUser(user);
        
        // Crear datos iniciales si es un usuario nuevo
        final hasData = await _userDataService.hasInitialData(user.uid);
        if (!hasData) {
          await _userDataService.createInitialUserData(user.uid);
        }
      }

      return user;
    } catch (e) {
      print('Error signing in with Google: $e');
      return null;
    }
  }

  // Crear o actualizar usuario en Firestore
  Future<void> _createOrUpdateUser(User user) async {
    final userDoc = _firestore.collection('users').doc(user.uid);
    final docSnapshot = await userDoc.get();

    if (!docSnapshot.exists) {
      // Crear nuevo usuario
      await userDoc.set({
        'uid': user.uid,
        'email': user.email,
        'display_name': user.displayName,
        'photo_url': user.photoURL,
        'provider': 'google',
        'user_role': _getUserRole(user.email ?? ''),
        'created_at': FieldValue.serverTimestamp(),
      });
    } else {
      // Actualizar usuario existente
      await userDoc.update({
        'display_name': user.displayName,
        'photo_url': user.photoURL,
        'last_login': FieldValue.serverTimestamp(),
      });
    }
  }

  // Determinar rol del usuario
  String _getUserRole(String email) {
    // Todos los usuarios tienen acceso completo a la app
    return 'Usuario';
  }

  // Logout
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Obtener datos del usuario desde Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }
}