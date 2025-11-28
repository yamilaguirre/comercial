import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  bool _isTracking = false;
  Position? _lastPosition;

  /// Inicia el seguimiento de ubicación para un trabajador
  Future<bool> startLocationTracking(String userId) async {
    if (_isTracking) return true;

    try {
      // Verificar permisos
      final hasPermission = await _checkAndRequestPermission();
      if (!hasPermission) {
        return false;
      }

      // Obtener ubicación actual
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _lastPosition = position;
      _isTracking = true;

      // Guardar en Firebase
      await _updateUserLocation(userId, position);

      // Escuchar cambios de ubicación (actualizar cada 100 metros o 5 minutos)
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 100, // metros
        ),
      ).listen((Position position) {
        _lastPosition = position;
        _updateUserLocation(userId, position);
      });

      return true;
    } catch (e) {
      print('Error iniciando tracking de ubicación: $e');
      return false;
    }
  }

  /// Detiene el seguimiento de ubicación
  void stopLocationTracking() {
    _isTracking = false;
  }

  /// Verifica y solicita permisos de ubicación
  Future<bool> _checkAndRequestPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Verificar si el servicio de ubicación está habilitado
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    // Verificar permisos
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Actualiza la ubicación del usuario en Firebase
  Future<void> _updateUserLocation(String userId, Position position) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'location': {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      });
    } catch (e) {
      print('Error actualizando ubicación en Firebase: $e');
    }
  }

  /// Obtiene la última posición conocida
  Position? get lastPosition => _lastPosition;

  /// Obtiene la ubicación actual sin iniciar tracking
  Future<Position?> getCurrentLocation() async {
    try {
      final hasPermission = await _checkAndRequestPermission();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return position;
    } catch (e) {
      print('Error obteniendo ubicación actual: $e');
      return null;
    }
  }

  /// Inicializa solo el campo de ubicación en el perfil del usuario
  /// Ya no inicializa rating ni reviews (se calculan dinámicamente)
  static Future<void> initializeWorkerProfile(String userId) async {
    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId);
      final doc = await userRef.get();
      final data = doc.data();

      // Solo inicializar ubicación si no existe
      final updates = <String, dynamic>{};

      if (data?['location'] == null) {
        // Intentar obtener ubicación actual
        final locationService = LocationService();
        final position = await locationService.getCurrentLocation();

        if (position != null) {
          updates['location'] = {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'accuracy': position.accuracy,
            'updatedAt': FieldValue.serverTimestamp(),
          };
        }
      }

      if (updates.isNotEmpty) {
        await userRef.update(updates);
      }
    } catch (e) {
      print('Error inicializando perfil de trabajador: $e');
    }
  }

  /// Actualiza la calificación del trabajador usando solo la colección feedback
  /// Los valores de rating y reviews se calculan dinámicamente, no se almacenan
  static Future<void> updateWorkerRating({
    required String workerId,
    required String ratingUserId,
    required double newRating,
  }) async {
    try {
      final feedbackRef = FirebaseFirestore.instance.collection('feedback');

      // Buscar si ya existe un feedback de este usuario para este trabajador
      final existingFeedback = await feedbackRef
          .where('workerId', isEqualTo: workerId)
          .where('userId', isEqualTo: ratingUserId)
          .limit(1)
          .get();

      if (existingFeedback.docs.isNotEmpty) {
        // Ya existe una calificación, actualizar solo el documento de feedback
        final feedbackId = existingFeedback.docs.first.id;

        await feedbackRef.doc(feedbackId).update({
          'rating': newRating,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // No existe, crear nuevo feedback
        await feedbackRef.add({
          'workerId': workerId,
          'userId': ratingUserId,
          'rating': newRating,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error actualizando calificación: $e');
    }
  }

  /// Calcula el rating promedio de un trabajador desde la colección feedback
  static Future<Map<String, dynamic>> calculateWorkerRating(
    String workerId,
  ) async {
    try {
      final feedbackSnapshot = await FirebaseFirestore.instance
          .collection('feedback')
          .where('workerId', isEqualTo: workerId)
          .get();

      if (feedbackSnapshot.docs.isEmpty) {
        return {'rating': 0.0, 'reviews': 0};
      }

      double totalRating = 0.0;
      int reviewCount = feedbackSnapshot.docs.length;

      for (var doc in feedbackSnapshot.docs) {
        final rating = (doc.data()['rating'] as num?)?.toDouble() ?? 0.0;
        totalRating += rating;
      }

      final averageRating = reviewCount > 0 ? totalRating / reviewCount : 0.0;

      return {'rating': averageRating, 'reviews': reviewCount};
    } catch (e) {
      print('Error calculando rating: $e');
      return {'rating': 0.0, 'reviews': 0};
    }
  }

  /// Stream que calcula el rating promedio de un trabajador en tiempo real
  /// Se actualiza automáticamente cuando cambia la colección feedback
  static Stream<Map<String, dynamic>> calculateWorkerRatingStream(
    String workerId,
  ) {
    return FirebaseFirestore.instance
        .collection('feedback')
        .where('workerId', isEqualTo: workerId)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            return {'rating': 0.0, 'reviews': 0};
          }

          double totalRating = 0.0;
          int reviewCount = snapshot.docs.length;

          for (var doc in snapshot.docs) {
            final rating = (doc.data()['rating'] as num?)?.toDouble() ?? 0.0;
            totalRating += rating;
          }

          final averageRating = reviewCount > 0
              ? totalRating / reviewCount
              : 0.0;

          return {'rating': averageRating, 'reviews': reviewCount};
        });
  }
}
