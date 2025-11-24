// services/property_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/property_model.dart';

class PropertyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Obtener todas las propiedades activas
  Stream<List<Property>> getActiveProperties() {
    return _firestore
        .collection('properties')
        .where('is_active', isEqualTo: true)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Property.fromFirestore(doc)).toList());
  }

  // Obtener propiedades por filtros
  Stream<List<Property>> getPropertiesByFilters({
    String? transactionType,
    String? propertyType,
    String? department,
    double? minPrice,
    double? maxPrice,
  }) {
    Query query = _firestore.collection('properties').where('is_active', isEqualTo: true);

    if (transactionType != null) {
      query = query.where('transaction_type', isEqualTo: transactionType);
    }
    if (propertyType != null) {
      query = query.where('property_type', isEqualTo: propertyType);
    }
    if (department != null) {
      query = query.where('department', isEqualTo: department);
    }

    return query.orderBy('created_at', descending: true).snapshots().map((snapshot) {
      var properties = snapshot.docs.map((doc) => Property.fromFirestore(doc)).toList();
      
      // Filtrar por precio en el cliente (Firestore no permite múltiples rangos)
      if (minPrice != null) {
        properties = properties.where((p) => p.price >= minPrice).toList();
      }
      if (maxPrice != null) {
        properties = properties.where((p) => p.price <= maxPrice).toList();
      }
      
      return properties;
    });
  }

  // Obtener propiedad por ID
  Future<Property?> getPropertyById(String propertyId) async {
    try {
      final doc = await _firestore.collection('properties').doc(propertyId).get();
      if (doc.exists) {
        return Property.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting property: $e');
      return null;
    }
  }

  // Obtener propiedades por lista de IDs
  Future<List<Property>> getPropertiesByIds(List<String> propertyIds) async {
    if (propertyIds.isEmpty) return [];
    
    try {
      final List<Property> properties = [];
      
      // Firestore 'in' query limit is 10, so we batch the requests
      for (int i = 0; i < propertyIds.length; i += 10) {
        final batch = propertyIds.skip(i).take(10).toList();
        final snapshot = await _firestore
            .collection('properties')
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        
        properties.addAll(snapshot.docs.map((doc) => Property.fromFirestore(doc)));
      }
      
      return properties;
    } catch (e) {
      print('Error getting properties by IDs: $e');
      return [];
    }
  }
}