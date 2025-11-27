# PATCH para worker_location_search_screen.dart

## Paso 1: Agregar import (línea 10, después de `auth_provider.dart`)

```dart
import '../../widgets/map_drawing_detector.dart';
```

El bloque de imports quedará así:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../theme/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/map_drawing_detector.dart';  // <-- AGREGAR ESTA LÍNEA
import 'premium_subscription_modal.dart';
```

## Paso 2: Agregar variable de estado (después de línea 41, después de `_selectedWorkerIndex`)

```dart
  // Estado del modo de dibujo
  bool _isDrawingMode = false;
```

Quedará así:
```dart
  // Controlador para el PageView de trabajadores
  late PageController _pageController;
  int _selectedWorkerIndex = -1;

  // Estado del modo de dibujo      // <-- AGREGAR ESTAS
  bool _isDrawingMode = false;      // <--  DOS LÍNEAS

  // Categorías disponibles con sus colores e iconos
  final Map<String, Map<String, dynamic>> _categoryStyles = {
```

## Paso 3: Agregar MapDrawingDetector (después del FlutterMap, antes de "Barra superior con filtros")

Buscar la línea que dice `// Barra superior con filtros` (aprox. línea 362) y ANTES de esa línea agregar:

```dart
          // Detector de dibujo en el mapa
          MapDrawingDetector(
            isEnabled: _isDrawingMode,
            mapController: _mapController,
            onCircleDetected: (LatLng center, double radiusKm) {
              setState(() {
                _userLocation = center;
                _mapCenter = center;
                _searchRadius = radiusKm.clamp(1.0, 20.0);
                _isDrawingMode = false;
              });
              _mapController.move(center, 14.5);
              _filterWorkersByLocation();
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '¡Círculo detectado! Radio: ${radiusKm.toStringAsFixed(1)} km',
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            onInvalidShape: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Figura no aceptada - Por favor dibuja un círculo'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),

```

## Paso 4: Agregar botón de dibujo (después de línea 467, antes del "Botón de ubicación")

Buscar donde dice `// Botón de ubicación` (aprox. línea 470) y ANTES agregar:

```dart
          // Botón de modo de dibujo
          Positioned(
            right: 16,
            bottom: 370,
            child: FloatingActionButton(
              heroTag: 'drawing_btn',
              backgroundColor: _isDrawingMode ? const Color(0xFF0033CC) : Colors.white,
              onPressed: () {
                setState(() {
                  _isDrawingMode = !_isDrawingMode;
                });
                if (_isDrawingMode) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Modo dibujo activado - Dibuja un círculo en el mapa'),
                      backgroundColor: Color(0xFF0033CC),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: Image.asset(
                'assets/images/icon/hand-draw.png',
                width: 30,
                height: 30,
                color: _isDrawingMode ? Colors.white : const Color(0xFF0033CC),
              ),
            ),
          ),

```

## ¡Listo!

Aplica estos 4 cambios en orden y la funcionalidad estará completa.
