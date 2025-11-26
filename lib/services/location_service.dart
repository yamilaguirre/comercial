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

  /// Inicializa los campos de ubicación y rating en el perfil del usuario
  static Future<void> initializeWorkerProfile(String userId) async {
    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId);
      final doc = await userRef.get();
      final data = doc.data();

      // Solo inicializar si no existen
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

      if (data?['rating'] == null) {
        updates['rating'] = 0.0;
      }

      if (data?['reviews'] == null) {
        updates['reviews'] = 0;
      }

      if (data?['totalRatingScore'] == null) {
        updates['totalRatingScore'] = 0.0;
      }

      if (updates.isNotEmpty) {
        await userRef.update(updates);
      }
    } catch (e) {
      print('Error inicializando perfil de trabajador: $e');
    }
  }

  /// Actualiza la calificación del trabajador
  static Future<void> updateWorkerRating({
    required String workerId,
    required double newRating,
  }) async {
    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(workerId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);

        if (!snapshot.exists) return;

        final data = snapshot.data()!;
        final currentReviews = (data['reviews'] as int?) ?? 0;
        final currentTotalScore =
            (data['totalRatingScore'] as num?)?.toDouble() ?? 0.0;

        final newReviews = currentReviews + 1;
        final newTotalScore = currentTotalScore + newRating;
        final newAverageRating = newTotalScore / newReviews;

        transaction.update(userRef, {
          'rating': newAverageRating,
          'reviews': newReviews,
          'totalRatingScore': newTotalScore,
          'lastRatingUpdate': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      print('Error actualizando calificación: $e');
    }
  }
}
