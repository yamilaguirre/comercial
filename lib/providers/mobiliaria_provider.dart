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
    if (user == null || user.uid.isEmpty) return [];

    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('properties')
          .where('owner_id', isEqualTo: user.uid)
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
    bool? isPremiumUser,
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

        // NUEVO: Configurar disponibilidad y expiración
        data['available'] = true; // Por defecto disponible
        // Calcular fecha de expiración (7 días desde ahora)
        final expirationDate = DateTime.now().add(const Duration(days: 7));
        data['expires_at'] = Timestamp.fromDate(expirationDate);
        data['last_published_at'] = FieldValue.serverTimestamp();
      }
      data['updated_at'] = FieldValue.serverTimestamp();

      String? newPropertyId;

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

        // Crear notificación si el precio bajó Y el usuario es premium
        if (isPremiumUser == true && oldPrice != null && newPrice != null) {
          final oldPriceNum = _parsePrice(oldPrice);
          final newPriceNum = _parsePrice(newPrice);

          if (newPriceNum < oldPriceNum) {
            // El precio bajó, crear notificación en notification_property
            await _notificationService
                .createPropertyNotificationInPropertyCollection(
                  type: NotificationType.priceDropHome,
                  title: '¡Rebaja de precio!',
                  message:
                      '${data['title'] ?? 'Una propiedad'} bajó de Bs ${_formatPrice(oldPriceNum)} a Bs ${_formatPrice(newPriceNum)}',
                  propertyId: propertyId,
                  oldPrice: oldPriceNum,
                  newPrice: newPriceNum,
                );
          }
        }
      } else {
        // Crear nueva propiedad
        final docRef = await _firestore.collection('properties').add(data);
        newPropertyId = docRef.id;

        // Si el usuario es premium, crear notificación global
        if (isPremiumUser == true) {
          final propertyTitle = data['title'] ?? 'Propiedad sin título';
          final propertyPrice =
              '${data['currency'] ?? 'BS'} ${data['price'] ?? '0'}';
          final propertyType = data['property_type'] ?? 'Propiedad';
          final location =
              '${data['department'] ?? 'Ubicación'}, ${data['zone_key'] ?? ''}';

          await _notificationService.createPremiumPropertyNotification(
            propertyId: newPropertyId,
            propertyTitle: propertyTitle,
            propertyPrice: propertyPrice,
            propertyType: propertyType,
            location: location,
          );
        }
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

  // --- GESTIÓN DE DISPONIBILIDAD ---

  /// Toggle availability de una propiedad (habilitar/deshabilitar)
  Future<bool> togglePropertyAvailability(
    String propertyId,
    bool newAvailability,
  ) async {
    User? user = _auth.currentUser;
    if (user == null) return false;

    try {
      await _firestore.collection('properties').doc(propertyId).update({
        'available': newAvailability,
        'updated_at': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      _errorMessage = 'Error al cambiar disponibilidad: $e';
      print('Error en togglePropertyAvailability: $_errorMessage');
      return false;
    }
  }

  /// Renovar fecha de publicación de una propiedad
  Future<bool> renewProperty(String propertyId) async {
    User? user = _auth.currentUser;
    if (user == null) return false;

    try {
      await _firestore.collection('properties').doc(propertyId).update({
        'last_published_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      _errorMessage = 'Error al renovar la propiedad: $e';
      print('Error en renewProperty: $_errorMessage');
      return false;
    }
  }
}
