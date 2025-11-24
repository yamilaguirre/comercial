import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/property.dart';

class MobiliariaProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // --- OBTENER PROPIEDADES DEL USUARIO ---
  Future<List<Property>> fetchUserProperties() async {
    User? user = _auth.currentUser;
    // DOBLE VERIFICACIÓN: Si el usuario es nulo o su UID es nulo/vacío, retornamos inmediatamente.
    if (user == null || user.uid.isEmpty) return [];

    _isLoading = true;
    notifyListeners();

    try {
      // Usamos user.uid, que contiene el ID de la sesión activa
      final snapshot = await _firestore
          .collection('properties')
          .where('owner_id', isEqualTo: user.uid) // CLAVE CORRECTA: 'owner_id'
          .orderBy('created_at', descending: true)
          .get();

      final properties = snapshot.docs
          .map((doc) => Property.fromFirestore(doc))
          .toList();
      return properties;
    } catch (e) {
      _errorMessage = 'Error al cargar tus propiedades: $e';
      print(
        'Error en fetchUserProperties: $_errorMessage',
      ); // Log para depuración
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- CREAR / ACTUALIZAR PROPIEDAD ---
  Future<bool> saveProperty(
    Map<String, dynamic> propertyData, {
    String? propertyId,
  }) async {
    User? user = _auth.currentUser;
    if (user == null) {
      _errorMessage =
          'Usuario no autenticado. No se puede guardar la propiedad.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final data = Map<String, dynamic>.from(propertyData);
      data['owner_id'] = user.uid; // CLAVE CORRECTA: 'owner_id'

      // Manejo de Timestamps
      if (propertyId == null) {
        data['created_at'] = FieldValue.serverTimestamp();
        data['is_active'] = true; // Por defecto activa al crear
      }
      data['updated_at'] = FieldValue.serverTimestamp();

      if (propertyId != null) {
        // Actualizar
        await _firestore.collection('properties').doc(propertyId).update(data);
      } else {
        // Crear
        await _firestore.collection('properties').add(data);
      }
      return true;
    } catch (e) {
      _errorMessage = 'Error al guardar la propiedad: $e';
      print('Error en saveProperty: $_errorMessage'); // Log para depuración
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- ELIMINAR PROPIEDAD ---
  Future<bool> deleteProperty(String propertyId) async {
    User? user = _auth.currentUser;
    if (user == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      // Verificar que el usuario sea el dueño (opcional pero recomendado)
      final doc = await _firestore
          .collection('properties')
          .doc(propertyId)
          .get();
      // Usar 'owner_id' para la verificación
      if (!doc.exists || doc.data()?['owner_id'] != user.uid) {
        _errorMessage = 'No tienes permiso para eliminar esta propiedad.';
        return false;
      }

      await _firestore.collection('properties').doc(propertyId).delete();
      return true;
    } catch (e) {
      _errorMessage = 'Error al eliminar la propiedad: $e';
      print('Error en deleteProperty: $_errorMessage'); // Log para depuración
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
