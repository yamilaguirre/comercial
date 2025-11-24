// services/saved_list_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/saved_list_model.dart';
import '../models/property_model.dart';
import 'property_service.dart';

class SavedListService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PropertyService _propertyService = PropertyService();

  // Obtener listas guardadas del usuario
  Stream<List<SavedList>> getUserSavedLists(String userId) {
    return _firestore
        .collection('saved_lists')
        .where('user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => SavedList.fromFirestore(doc)).toList());
  }

  // Obtener propiedades de una lista guardada
  Future<List<Property>> getPropertiesFromSavedList(String listId) async {
    try {
      final listDoc = await _firestore.collection('saved_lists').doc(listId).get();
      if (!listDoc.exists) return [];

      final savedList = SavedList.fromFirestore(listDoc);
      return await _propertyService.getPropertiesByIds(savedList.propertyIds);
    } catch (e) {
      print('Error getting properties from saved list: $e');
      return [];
    }
  }

  // Crear nueva lista guardada
  Future<bool> createSavedList(String userId, String listName, List<String> propertyIds) async {
    try {
      await _firestore.collection('saved_lists').add({
        'user_id': userId,
        'list_name': listName,
        'property_ids': propertyIds,
        'created_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error creating saved list: $e');
      return false;
    }
  }

  // Agregar propiedad a lista existente
  Future<bool> addPropertyToList(String listId, String propertyId) async {
    try {
      await _firestore.collection('saved_lists').doc(listId).update({
        'property_ids': FieldValue.arrayUnion([propertyId]),
      });
      return true;
    } catch (e) {
      print('Error adding property to list: $e');
      return false;
    }
  }

  // Remover propiedad de lista
  Future<bool> removePropertyFromList(String listId, String propertyId) async {
    try {
      await _firestore.collection('saved_lists').doc(listId).update({
        'property_ids': FieldValue.arrayRemove([propertyId]),
      });
      return true;
    } catch (e) {
      print('Error removing property from list: $e');
      return false;
    }
  }
}