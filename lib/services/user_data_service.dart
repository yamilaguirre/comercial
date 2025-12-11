// services/user_data_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Crear datos iniciales para un nuevo usuario
  Future<void> createInitialUserData(String userId) async {
    final batch = _firestore.batch();
    final now = DateTime.now();

    // Crear lista de favoritos inicial
    batch.set(_firestore.collection('saved_lists').doc(), {
      "user_id": userId,
      "list_name": "Mis Favoritos",
      "property_ids": [],
      "created_at": FieldValue.serverTimestamp(),
    });

    // Crear notificación de bienvenida
    batch.set(_firestore.collection('notifications').doc(), {
      "user_id": userId,
      "type": "system",
      "title": "¡Bienvenido!",
      "message": "Tu cuenta ha sido configurada. Explora las propiedades disponibles.",
      "property_id": null,
      "is_read": false,
      "created_at": FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // Verificar si el usuario ya tiene datos iniciales
  Future<bool> hasInitialData(String userId) async {
    final savedLists = await _firestore
        .collection('saved_lists')
        .where('user_id', isEqualTo: userId)
        .limit(1)
        .get();
    
    return savedLists.docs.isNotEmpty;
  }
}
