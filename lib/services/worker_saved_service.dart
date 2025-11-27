// services/worker_saved_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/saved_collection_model.dart';
import '../models/contact_filter.dart';

class WorkerSavedService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Obtener colecciones de trabajadores del usuario
  Stream<List<SavedCollection>> getUserCollections(String userId) {
    return _firestore
        .collection('worker_collections')
        .where('user_id', isEqualTo: userId)
        // .orderBy('updated_at', descending: true) // Comentado para evitar error de índice
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
          .collection('worker_collections')
          .doc(collectionId)
          .get();
      if (!doc.exists) return null;
      return SavedCollection.fromFirestore(doc);
    } catch (e) {
      print('Error getting collection: $e');
      return null;
    }
  }

  // Obtener trabajadores de una colección
  Future<List<Map<String, dynamic>>> getWorkersFromCollection(
    String collectionId,
  ) async {
    try {
      final collection = await getCollection(collectionId);
      if (collection == null) return [];

      if (collection.propertyIds.isEmpty)
        return []; // Usando propertyIds como workerIds

      // Obtener trabajadores desde la colección 'users' con rol de trabajador
      final workersSnapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: collection.propertyIds)
          .get();

      return workersSnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      print('Error getting workers from collection: $e');
      return [];
    }
  }

  // Obtener todos los trabajadores guardados del usuario
  Future<List<Map<String, dynamic>>> getAllSavedWorkers(String userId) async {
    try {
      // Primero intentar obtener desde favoriteWorkers en el documento del usuario
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final favoriteWorkers =
          (userDoc.data()?['favoriteWorkers'] as List<dynamic>?) ?? [];

      if (favoriteWorkers.isEmpty) return [];

      final workerIds = favoriteWorkers.cast<String>();

      // Obtener información de los trabajadores
      final workersSnapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: workerIds)
          .get();

      return workersSnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      print('Error getting all saved workers: $e');
      return [];
    }
  }

  // Crear nueva colección de trabajadores
  Future<String?> createCollection(String userId, String name) async {
    try {
      final docRef = await _firestore.collection('worker_collections').add({
        'user_id': userId,
        'name': name,
        'property_ids':
            [], // Mantener nombre por compatibilidad con SavedCollection model
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
      await _firestore
          .collection('worker_collections')
          .doc(collectionId)
          .update({
            'name': newName,
            'updated_at': FieldValue.serverTimestamp(),
          });
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
          .collection('worker_collections')
          .doc(collectionId)
          .delete();
      return true;
    } catch (e) {
      print('Error deleting collection: $e');
      return false;
    }
  }

  // Agregar trabajador a colección
  Future<bool> addWorkerToCollection(
    String collectionId,
    String workerId,
  ) async {
    try {
      await _firestore
          .collection('worker_collections')
          .doc(collectionId)
          .update({
            'property_ids': FieldValue.arrayUnion([workerId]),
            'updated_at': FieldValue.serverTimestamp(),
          });
      return true;
    } catch (e) {
      print('Error adding worker to collection: $e');
      return false;
    }
  }

  // Remover trabajador de colección
  Future<bool> removeWorkerFromCollection(
    String collectionId,
    String workerId,
  ) async {
    try {
      await _firestore
          .collection('worker_collections')
          .doc(collectionId)
          .update({
            'property_ids': FieldValue.arrayRemove([workerId]),
            'updated_at': FieldValue.serverTimestamp(),
          });
      return true;
    } catch (e) {
      print('Error removing worker from collection: $e');
      return false;
    }
  }

  // Verificar si un trabajador está guardado
  Future<bool> isWorkerSaved(String userId, String workerId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final favoriteWorkers =
          (userDoc.data()?['favoriteWorkers'] as List<dynamic>?) ?? [];
      return favoriteWorkers.contains(workerId);
    } catch (e) {
      print('Error checking if worker is saved: $e');
      return false;
    }
  }

  // Obtener colecciones que contienen un trabajador
  Future<List<SavedCollection>> getCollectionsWithWorker(
    String userId,
    String workerId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('worker_collections')
          .where('user_id', isEqualTo: userId)
          .where('property_ids', arrayContains: workerId)
          .get();

      return snapshot.docs
          .map((doc) => SavedCollection.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting collections with worker: $e');
      return [];
    }
  }

  // Contar total de trabajadores guardados
  Future<int> getTotalSavedCount(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final favoriteWorkers =
          (userDoc.data()?['favoriteWorkers'] as List<dynamic>?) ?? [];
      return favoriteWorkers.length;
    } catch (e) {
      print('Error getting total saved count: $e');
      return 0;
    }
  }

  // Obtener IDs de trabajadores contactados (donde existe un chat)
  Future<Set<String>> getContactedWorkerIds(String userId) async {
    try {
      // Buscar chats donde el usuario es participante
      final chatsSnapshot = await _firestore
          .collection('chats')
          .where('user_ids', arrayContains: userId)
          .get();

      final contactedIds = <String>{};
      for (var doc in chatsSnapshot.docs) {
        final data = doc.data();
        final userIds = List<String>.from(data['user_ids'] ?? []);

        // Encontrar el ID del otro usuario (el trabajador)
        final otherUserId = userIds.firstWhere(
          (id) => id != userId,
          orElse: () => '',
        );

        if (otherUserId.isNotEmpty) {
          contactedIds.add(otherUserId);
        }
      }
      return contactedIds;
    } catch (e) {
      print('Error getting contacted worker IDs: $e');
      return {};
    }
  }

  // Obtener trabajadores guardados filtrados por estado de contacto
  Future<List<Map<String, dynamic>>> getFilteredSavedWorkers(
    String userId,
    ContactFilter filter,
  ) async {
    try {
      // Obtener todos los trabajadores guardados
      final allSavedWorkers = await getAllSavedWorkers(userId);

      if (filter == ContactFilter.all) {
        return allSavedWorkers;
      }

      // Obtener IDs de trabajadores contactados
      final contactedIds = await getContactedWorkerIds(userId);

      // Filtrar según el tipo
      if (filter == ContactFilter.contacted) {
        return allSavedWorkers
            .where((worker) => contactedIds.contains(worker['id']))
            .toList();
      } else {
        // ContactFilter.notContacted
        return allSavedWorkers
            .where((worker) => !contactedIds.contains(worker['id']))
            .toList();
      }
    } catch (e) {
      print('Error getting filtered saved workers: $e');
      return [];
    }
  }

  // Contar trabajadores por estado de contacto
  Future<Map<ContactFilter, int>> getContactStatusCounts(String userId) async {
    try {
      final allSavedWorkers = await getAllSavedWorkers(userId);
      final contactedIds = await getContactedWorkerIds(userId);

      final contactedCount = allSavedWorkers
          .where((worker) => contactedIds.contains(worker['id']))
          .length;
      final notContactedCount = allSavedWorkers.length - contactedCount;

      return {
        ContactFilter.all: allSavedWorkers.length,
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

  // Contar trabajadores contactados (wrapper para compatibilidad)
  Future<int> getContactedCount(String userId) async {
    final counts = await getContactStatusCounts(userId);
    return counts[ContactFilter.contacted] ?? 0;
  }
}
