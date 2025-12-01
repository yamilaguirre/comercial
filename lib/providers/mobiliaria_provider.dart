import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/property.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

class MobiliariaProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

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
        data['favorites'] = 0; // Inicializar contador de favoritos
      }
      data['updated_at'] = FieldValue.serverTimestamp();

      if (propertyId != null) {
        // Obtener el precio anterior para comparar
        final oldDoc = await _firestore
            .collection('properties')
            .doc(propertyId)
            .get();

        final oldPrice = oldDoc.data()?['price'];
        final newPrice = data['price'];

        // Actualizar
        await _firestore.collection('properties').doc(propertyId).update(data);

        // Crear notificación si el precio bajó
        if (oldPrice != null && newPrice != null) {
          final oldPriceNum = _parsePrice(oldPrice);
          final newPriceNum = _parsePrice(newPrice);

          if (newPriceNum < oldPriceNum) {
            // El precio bajó, crear notificación
            await _notificationService.createPropertyNotification(
              type: NotificationType.priceDropHome,
              title: '¡Rebaja de precio!',
              message:
                  '${data['name'] ?? 'Una propiedad'} bajó de Bs ${_formatPrice(oldPriceNum)} a Bs ${_formatPrice(newPriceNum)}',
              propertyId: propertyId,
              oldPrice: oldPriceNum,
              newPrice: newPriceNum,
            );
          }
        }
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

  // Helper para parsear precio (puede ser String o num)
  double _parsePrice(dynamic price) {
    if (price is num) return price.toDouble();
    if (price is String) {
      // Remover caracteres no numéricos excepto punto y coma
      final cleaned = price.replaceAll(RegExp(r'[^0-9.]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  // Helper para formatear precio
  String _formatPrice(double price) {
    return price
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
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

  // --- ANALYTICS (VISTAS Y CONSULTAS) ---

  // Incrementar contador de vistas
  Future<void> incrementPropertyView(String propertyId) async {
    try {
      await _firestore.collection('properties').doc(propertyId).update({
        'views': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error incrementing views for property $propertyId: $e');
      // No mostramos error al usuario por esto, es silencioso
    }
  }

  // Incrementar contador de consultas (Chat/WhatsApp)
  Future<void> incrementPropertyInquiry(String propertyId) async {
    try {
      await _firestore.collection('properties').doc(propertyId).update({
        'inquiries': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error incrementing inquiries for property $propertyId: $e');
      // No mostramos error al usuario por esto, es silencioso
    }
  }
}
