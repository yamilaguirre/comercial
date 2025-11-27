import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/saved_collection_model.dart';
import '../models/property.dart';
import '../models/contact_filter.dart';

class SavedListService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Obtener colecciones del usuario
  Stream<List<SavedCollection>> getUserCollections(String userId) {
    return _firestore
        .collection('saved_collections')
        .where('user_id', isEqualTo: userId)
        .orderBy('updated_at', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SavedCollection.fromFirestore(doc))
              .toList(),
        );
  }

  // Obtener colección específica
  Future<SavedCollection?> getCollection(String collectionId) async {
    try {
      final doc = await _firestore
          .collection('saved_collections')
          .doc(collectionId)
          .get();
      if (!doc.exists) return null;
      return SavedCollection.fromFirestore(doc);
    } catch (e) {
      print('Error getting collection: $e');
      return null;
    }
  }

  // Obtener propiedades de una colección
  Future<List<Property>> getPropertiesFromCollection(
    String collectionId,
  ) async {
    try {
      final collection = await getCollection(collectionId);
      if (collection == null) return [];

      if (collection.propertyIds.isEmpty) return [];

      final propertiesSnapshot = await _firestore
          .collection('properties')
          .where(FieldPath.documentId, whereIn: collection.propertyIds)
          .get();

      return propertiesSnapshot.docs
          .map((doc) => Property.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting properties from collection: $e');
      return [];
    }
  }

  // Obtener todas las propiedades guardadas del usuario
  Future<List<Property>> getAllSavedProperties(String userId) async {
    try {
      final collectionsSnapshot = await _firestore
          .collection('saved_collections')
          .where('user_id', isEqualTo: userId)
          .get();

      final allPropertyIds = <String>{};
      for (var doc in collectionsSnapshot.docs) {
        final collection = SavedCollection.fromFirestore(doc);
        allPropertyIds.addAll(collection.propertyIds);
      }

      if (allPropertyIds.isEmpty) return [];

      final propertiesSnapshot = await _firestore
          .collection('properties')
          .where(FieldPath.documentId, whereIn: allPropertyIds.toList())
          .get();

      return propertiesSnapshot.docs
          .map((doc) => Property.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting all saved properties: $e');
      return [];
    }
  }

  // Crear nueva colección
  Future<String?> createCollection(String userId, String name) async {
    try {
      final docRef = await _firestore.collection('saved_collections').add({
        'user_id': userId,
        'name': name,
        'property_ids': [],
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      print('Error creating collection: $e');
      return null;
    }
  }

  // Actualizar nombre de colección
  Future<bool> updateCollectionName(String collectionId, String newName) async {
    try {
      await _firestore.collection('saved_collections').doc(collectionId).update(
        {'name': newName, 'updated_at': FieldValue.serverTimestamp()},
      );
      return true;
    } catch (e) {
      print('Error updating collection name: $e');
      return false;
    }
  }

  // Eliminar colección
  Future<bool> deleteCollection(String collectionId) async {
    try {
      await _firestore
          .collection('saved_collections')
          .doc(collectionId)
          .delete();
      return true;
    } catch (e) {
      print('Error deleting collection: $e');
      return false;
    }
  }

  // Agregar propiedad a colección
  Future<bool> addPropertyToCollection(
    String collectionId,
    String propertyId,
  ) async {
    try {
      await _firestore.collection('saved_collections').doc(collectionId).update(
        {
          'property_ids': FieldValue.arrayUnion([propertyId]),
          'updated_at': FieldValue.serverTimestamp(),
        },
      );
      return true;
    } catch (e) {
      print('Error adding property to collection: $e');
      return false;
    }
  }

  // Remover propiedad de colección
  Future<bool> removePropertyFromCollection(
    String collectionId,
    String propertyId,
  ) async {
    try {
      await _firestore.collection('saved_collections').doc(collectionId).update(
        {
          'property_ids': FieldValue.arrayRemove([propertyId]),
          'updated_at': FieldValue.serverTimestamp(),
        },
      );
      return true;
    } catch (e) {
      print('Error removing property from collection: $e');
      return false;
    }
  }

  // Verificar si una propiedad está guardada
  Future<bool> isPropertySaved(String userId, String propertyId) async {
    try {
      final snapshot = await _firestore
          .collection('saved_collections')
          .where('user_id', isEqualTo: userId)
          .where('property_ids', arrayContains: propertyId)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking if property is saved: $e');
      return false;
    }
  }

  // Obtener colecciones que contienen una propiedad
  Future<List<SavedCollection>> getCollectionsWithProperty(
    String userId,
    String propertyId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('saved_collections')
          .where('user_id', isEqualTo: userId)
          .where('property_ids', arrayContains: propertyId)
          .get();

      return snapshot.docs
          .map((doc) => SavedCollection.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting collections with property: $e');
      return [];
    }
  }

  // Contar total de propiedades guardadas
  Future<int> getTotalSavedCount(String userId) async {
    try {
      final collections = await getUserCollections(userId).first;
      final allPropertyIds = <String>{};
      for (var collection in collections) {
        allPropertyIds.addAll(collection.propertyIds);
      }
      return allPropertyIds.length;
    } catch (e) {
      print('Error getting total saved count: $e');
      return 0;
    }
  }

  // Obtener IDs de propiedades contactadas (donde existe un chat)
  Future<Set<String>> getContactedPropertyIds(String userId) async {
    try {
      final chatsSnapshot = await _firestore
          .collection('chats')
          .where('user_ids', arrayContains: userId)
          .get();

      final contactedIds = <String>{};
      for (var doc in chatsSnapshot.docs) {
        final propertyId = doc.data()['property_id'] as String?;
        if (propertyId != null && propertyId.isNotEmpty) {
          contactedIds.add(propertyId);
        }
      }
      return contactedIds;
    } catch (e) {
      print('Error getting contacted property IDs: $e');
      return {};
    }
  }

  // Obtener propiedades guardadas filtradas por estado de contacto
  Future<List<Property>> getFilteredSavedProperties(
    String userId,
    ContactFilter filter,
  ) async {
    try {
      // Obtener todas las propiedades guardadas
      final allSavedProperties = await getAllSavedProperties(userId);

      if (filter == ContactFilter.all) {
        return allSavedProperties;
      }

      // Obtener IDs de propiedades contactadas
      final contactedIds = await getContactedPropertyIds(userId);

      // Filtrar según el tipo
      if (filter == ContactFilter.contacted) {
        return allSavedProperties
            .where((property) => contactedIds.contains(property.id))
            .toList();
      } else {
        // ContactFilter.notContacted
        return allSavedProperties
            .where((property) => !contactedIds.contains(property.id))
            .toList();
      }
    } catch (e) {
      print('Error getting filtered saved properties: $e');
      return [];
    }
  }

  // Contar propiedades por estado de contacto
  Future<Map<ContactFilter, int>> getContactStatusCounts(String userId) async {
    try {
      final allSavedProperties = await getAllSavedProperties(userId);
      final contactedIds = await getContactedPropertyIds(userId);

      final contactedCount = allSavedProperties
          .where((property) => contactedIds.contains(property.id))
          .length;
      final notContactedCount = allSavedProperties.length - contactedCount;

      return {
        ContactFilter.all: allSavedProperties.length,
        ContactFilter.contacted: contactedCount,
        ContactFilter.notContacted: notContactedCount,
      };
    } catch (e) {
      print('Error getting contact status counts: $e');
      return {
        ContactFilter.all: 0,
        ContactFilter.contacted: 0,
        ContactFilter.notContacted: 0,
      };
    }
  }
}
