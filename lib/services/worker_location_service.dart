// services/worker_location_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/worker_location_model.dart';

class WorkerLocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Colecciones
  final String _locationsCollection = 'worker_locations';
  final String _usersCollection = 'users';

  /// Crear nueva ubicación
  Future<String> createLocation(WorkerLocation location) async {
    try {
      final docRef = await _firestore
          .collection(_locationsCollection)
          .add(location.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Error al crear ubicación: $e');
    }
  }

  /// Obtener ubicaciones del usuario
  Stream<List<WorkerLocation>> getUserLocations(String userId) {
    return _firestore
        .collection(_locationsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => WorkerLocation.fromFirestore(doc))
              .toList(),
        );
  }

  /// Obtener ubicación específica
  Future<WorkerLocation?> getLocation(String locationId) async {
    try {
      final doc = await _firestore
          .collection(_locationsCollection)
          .doc(locationId)
          .get();
      if (doc.exists) {
        return WorkerLocation.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Obtener ubicación activa del usuario
  Future<WorkerLocation?> getActiveLocation(String userId) async {
    try {
      // Primero obtenemos la configuración del usuario
      final userDoc = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .get();
      final locationSettings = LocationSettings.fromMap(
        userDoc.data()?['locationSettings'] as Map<String, dynamic>?,
      );

      if (locationSettings.activeLocationId != null) {
        return await getLocation(locationSettings.activeLocationId!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Actualizar ubicación
  Future<void> updateLocation(
    String locationId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore
          .collection(_locationsCollection)
          .doc(locationId)
          .update(data);
    } catch (e) {
      throw Exception('Error al actualizar ubicación: $e');
    }
  }

  /// Eliminar ubicación
  Future<void> deleteLocation(String locationId) async {
    try {
      await _firestore
          .collection(_locationsCollection)
          .doc(locationId)
          .delete();
    } catch (e) {
      throw Exception('Error al eliminar ubicación: $e');
    }
  }

  /// Actualizar configuración de visibilidad del usuario
  Future<void> updateLocationSettings({
    required String userId,
    required bool showOnMap,
    required String locationType,
    String? activeLocationId,
  }) async {
    try {
      final settings = LocationSettings(
        showOnMap: showOnMap,
        locationType: locationType,
        activeLocationId: activeLocationId,
      );

      final data = <String, dynamic>{'locationSettings': settings.toMap()};

      // Si cambiamos a ubicación fija y tenemos una activa, actualizar coordenadas
      if (locationType == 'fixed' && activeLocationId != null) {
        final locationDoc = await _firestore
            .collection(_locationsCollection)
            .doc(activeLocationId)
            .get();
        if (locationDoc.exists) {
          final location = WorkerLocation.fromFirestore(locationDoc);
          data['location'] = {
            'latitude': location.geopoint.latitude,
            'longitude': location.geopoint.longitude,
            'accuracy': 0.0, // Indicar que es fija
            'updatedAt': FieldValue.serverTimestamp(),
            'isFixed': true, // Flag para identificar
            'locationName': location.name, // Sync name
            'locationAddress': location.address, // Sync address
            'locationType': location.type, // Sync type (workshop/home)
          };
        }
      }

      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Error al actualizar configuración: $e');
    }
  }

  /// Obtener configuración de ubicación del usuario
  Future<LocationSettings> getLocationSettings(String userId) async {
    try {
      final userDoc = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .get();
      return LocationSettings.fromMap(
        userDoc.data()?['locationSettings'] as Map<String, dynamic>?,
      );
    } catch (e) {
      return LocationSettings(
        showOnMap: true,
        locationType: 'fixed',
        activeLocationId: null,
      );
    }
  }

  /// Activar una ubicación específica
  Future<void> setActiveLocation(String userId, String locationId) async {
    debugPrint('🔧 Activando ubicación: $locationId para usuario: $userId');

    try {
      // Marcar todas las ubicaciones como inactivas
      final userLocations = await _firestore
          .collection(_locationsCollection)
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in userLocations.docs) {
        await doc.reference.update({'isActive': false});
      }

      // Marcar la nueva como activa
      await _firestore.collection(_locationsCollection).doc(locationId).update({
        'isActive': true,
      });

      // Actualizar en locationSettings
      final currentSettings = await getLocationSettings(userId);
      await updateLocationSettings(
        userId: userId,
        showOnMap: currentSettings.showOnMap,
        locationType: currentSettings.locationType,
        activeLocationId: locationId,
      );

      debugPrint('🔧 Settings actualizados, activeLocationId: $locationId');

      // Actualizar coordenadas en el perfil del usuario
      final locationDoc = await _firestore
          .collection(_locationsCollection)
          .doc(locationId)
          .get();
      if (locationDoc.exists) {
        final location = WorkerLocation.fromFirestore(locationDoc);
        debugPrint(
          '🔧 Sincronizando ubicación a users: ${location.name} (${location.type})',
        );

        await _firestore.collection(_usersCollection).doc(userId).update({
          'location': {
            'latitude': location.geopoint.latitude,
            'longitude': location.geopoint.longitude,
            'accuracy': 0.0,
            'updatedAt': FieldValue.serverTimestamp(),
            'isFixed': true,
            'locationName': location.name,
            'locationAddress': location.address,
            'locationType': location.type,
          },
        });

        debugPrint('✅ Ubicación sincronizada correctamente a users');
      } else {
        debugPrint('❌ No se encontró el documento de ubicación: $locationId');
      }
    } catch (e) {
      debugPrint('❌ Error en setActiveLocation: $e');
      rethrow;
    }
  }
}
