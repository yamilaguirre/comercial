import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:geolocator/geolocator.dart'; // Importante para GPS
import '../../theme/theme.dart';

// --- CONSTANTES DE MAPA (TOKEN REAL) ---
const String _mapboxAccessToken =
    'pk.eyJ1IjoibXVqZXJlc2Fsdm9sYW50ZSIsImEiOiJjbWFoZTR1ZzEwYXdvMmtxMHg5ZXZneXgyIn0.9aNpyQyi5wP1qKi0SjiR5Q';
const String _mapboxStyleId = 'mapbox/streets-v12';

class MapPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const MapPickerScreen({super.key, this.initialLat, this.initialLng});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late final MapController _mapController;
  late LatLng _center;
  bool _isLocating = false; // Nuevo estado para el loading del GPS

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    // Establecer la ubicación central inicial (usando fallback de Cochabamba)
    _center = LatLng(
      widget.initialLat ?? -17.3938,
      widget.initialLng ?? -66.1571,
    );

    // Ejecutar la lógica de movimiento después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Centrar el mapa si ya está listo
        _mapController.move(_center, 15.0);
      }
    });
  }

  void _onMapPositionChanged(MapCamera camera, bool hasGesture) {
    // Actualizamos el estado de la posición central para el botón de confirmación
    setState(() {
      _center = camera.center;
    });
  }

  // --- FUNCIÓN PARA OBTENER Y CENTRAR EN EL GPS ---
  Future<void> _getCurrentLocationAndCenter() async {
    setState(() => _isLocating = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Permiso de ubicación denegado.')),
            );
          }
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final newLocation = LatLng(position.latitude, position.longitude);

      // Mueve el mapa al nuevo punto y actualiza el estado
      if (mounted) {
        _mapController.move(newLocation, 16.0);
        setState(() {
          _center = newLocation;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ubicación actualizada por GPS')),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo obtener la ubicación GPS.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _confirmLocation() {
    if (_center != null) {
      // Devolver la ubicación seleccionada
      Modular.to.pop(_center);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Modular.to.pop(),
          ),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              // Usamos _center en la inicialización
              initialCenter: _center,
              initialZoom: 15.0,
              onPositionChanged: _onMapPositionChanged,
            ),
            children: [
              // --- MAPBOX TILE LAYER ---
              TileLayer(
                urlTemplate:
                    'https://api.mapbox.com/styles/v1/$_mapboxStyleId/tiles/256/{z}/{x}/{y}@2x?access_token=$_mapboxAccessToken',
                userAgentPackageName: 'com.mobiliaria.app',
              ),
            ],
          ),

          // Pin central (indicador de ubicación)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on,
                    color: Styles.primaryColor,
                    size: 50,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  Container(
                    width: 10,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tarjeta Flotante con Botones
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- NUEVO BOTÓN: USAR MI GPS ---
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isLocating
                          ? null
                          : _getCurrentLocationAndCenter,
                      icon: _isLocating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Styles.primaryColor,
                              ),
                            )
                          : const Icon(Icons.my_location, size: 20),
                      label: Text(
                        _isLocating
                            ? 'Obteniendo Ubicación...'
                            : 'Situar en mi dirección actual',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Styles.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(
                            color: Styles.primaryColor,
                            width: 1.5,
                          ),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12), // Separador
                  // BOTÓN: CONFIRMAR UBICACIÓN
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _confirmLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Styles.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Confirmar Ubicación',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
