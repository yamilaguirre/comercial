import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/property.dart';
import '../../widgets/map_drawing_detector.dart';
import '../../utils/map_geometry_utils.dart';
import '../../theme/theme.dart';

// Token de Mapbox
const String _mapboxAccessToken =
    'pk.eyJ1IjoibXVqZXJlc2Fsdm9sYW50ZSIsImEiOiJjbWFoZTR1ZzEwYXdvMmtxMHg5ZXZneXgyIn0.9aNpyQyi5wP1qKi0SjiR5Q';
const String _mapboxStyleId = 'mapbox/streets-v12';

class PropertyLocationSearchScreen extends StatefulWidget {
  const PropertyLocationSearchScreen({super.key});

  @override
  State<PropertyLocationSearchScreen> createState() =>
      _PropertyLocationSearchScreenState();
}

class _PropertyLocationSearchScreenState
    extends State<PropertyLocationSearchScreen> {
  late final MapController _mapController;
  LatLng _mapCenter = const LatLng(-17.3938, -66.1571);
  LatLng? _userLocation;
  bool _isLocating = false;
  double _searchRadius = 5.0;

  List<Property> _properties = [];
  List<Property> _filteredProperties = [];
  int _selectedPropertyIndex = -1;
  bool _isDrawingMode = false;
  List<LatLng>? _searchPolygon;

  final Map<String, Map<String, dynamic>> _categoryStyles = {
    'casa': {
      'color': const Color(0xFF2196F3),
      'icon': Icons.home,
      'label': 'Casa',
    },
    'departamento': {
      'color': const Color(0xFF9C27B0),
      'icon': Icons.apartment,
      'label': 'Departamento',
    },
    'terreno': {
      'color': const Color(0xFF4CAF50),
      'icon': Icons.landscape,
      'label': 'Terreno',
    },
    'oficina': {
      'color': const Color(0xFFF44336),
      'icon': Icons.business,
      'label': 'Oficina',
    },
    'local_comercial': {
      'color': const Color(0xFFFF9800),
      'icon': Icons.store,
      'label': 'Local Comercial',
    },
  };

  final Map<String, Map<String, dynamic>> _transactionStyles = {
    'sale': {
      'color': const Color(0xFF00BCD4),
      'icon': Icons.sell,
      'label': 'Venta',
    },
    'rent': {
      'color': const Color(0xFFFF5722),
      'icon': Icons.key,
      'label': 'Alquiler',
    },
    'anticretico': {
      'color': const Color(0xFF673AB7),
      'icon': Icons.handshake,
      'label': 'Anticrético',
    },
  };

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _getCurrentLocation();
    _loadProperties();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _isLocating = false);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) {
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
          _mapCenter = _userLocation!;
          _isLocating = false;
        });
        _mapController.move(_mapCenter, 14.5);
        _applyFilters();
      }
    } catch (e) {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _loadProperties() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('properties')
          .where('is_active', isEqualTo: true)
          .get();
      final properties = <Property>[];
      for (var doc in snapshot.docs) {
        try {
          final property = Property.fromFirestore(doc);
          if (property.latitude != 0.0 && property.longitude != 0.0) {
            properties.add(property);
          }
        } catch (e) {
          debugPrint('Error parsing property ${doc.id}: $e');
        }
      }
      setState(() {
        _properties = properties;
        _applyFilters();
      });
    } catch (e) {
      debugPrint('Error loading properties: $e');
    }
  }

  // Método unificado que aplica filtros según el modo activo
  void _applyFilters() {
    if (_searchPolygon != null && _searchPolygon!.isNotEmpty) {
      _filterPropertiesByPolygon();
    } else {
      _filterPropertiesByLocation();
    }
  }

  void _filterPropertiesByLocation() {
    if (_userLocation == null) return;
    final filtered = _properties.where((property) {
      final distance = Geolocator.distanceBetween(
        _userLocation!.latitude,
        _userLocation!.longitude,
        property.latitude,
        property.longitude,
      );
      return (distance / 1000) <= _searchRadius;
    }).toList();
    filtered.sort((a, b) {
      final distanceA = Geolocator.distanceBetween(
        _userLocation!.latitude,
        _userLocation!.longitude,
        a.latitude,
        a.longitude,
      );
      final distanceB = Geolocator.distanceBetween(
        _userLocation!.latitude,
        _userLocation!.longitude,
        b.latitude,
        b.longitude,
      );
      return distanceA.compareTo(distanceB);
    });
    setState(() => _filteredProperties = filtered);
  }

  void _filterPropertiesByPolygon() {
    if (_searchPolygon == null || _searchPolygon!.isEmpty) return;
    final filtered = _properties.where((property) {
      final propertyLocation = LatLng(property.latitude, property.longitude);

      // Solo verificar si está dentro del polígono
      return MapGeometryUtils.isPointInPolygon(
        propertyLocation,
        _searchPolygon!,
      );
    }).toList();
    final center = MapGeometryUtils.calculateCentroid(_searchPolygon!);
    filtered.sort((a, b) {
      final distanceA = MapGeometryUtils.calculateDistance(
        center,
        LatLng(a.latitude, a.longitude),
      );
      final distanceB = MapGeometryUtils.calculateDistance(
        center,
        LatLng(b.latitude, b.longitude),
      );
      return distanceA.compareTo(distanceB);
    });
    setState(() => _filteredProperties = filtered);
  }



  Color _getPropertyColor(String propertyType) {
    final typeKey = propertyType.toLowerCase();
    return _categoryStyles[typeKey]?['color'] ?? Styles.primaryColor;
  }

  IconData _getPropertyIcon(String propertyType) {
    final typeKey = propertyType.toLowerCase();
    return _categoryStyles[typeKey]?['icon'] ?? Icons.home;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: 14.5,
              minZoom: 10.0,
              maxZoom: 18.0,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) setState(() => _isLocating = false);
              },
              onTap: (_, __) {
                if (_selectedPropertyIndex != -1) {
                  setState(() => _selectedPropertyIndex = -1);
                }
              },
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://api.mapbox.com/styles/v1/$_mapboxStyleId/tiles/256/{z}/{x}/{y}?access_token=$_mapboxAccessToken',
                userAgentPackageName: 'com.mobiliaria.app',
                tileProvider: NetworkTileProvider(),
                maxNativeZoom: 18,
                maxZoom: 18,
                minZoom: 10,
                keepBuffer: 2,
              ),
              if (_searchPolygon != null && _searchPolygon!.isNotEmpty)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: _searchPolygon!,
                      color: Styles.primaryColor.withOpacity(0.15),
                      borderColor: Styles.primaryColor,
                      borderStrokeWidth: 3.0,
                      isFilled: true,
                    ),
                  ],
                ),
              if (_userLocation != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _userLocation!,
                      radius: _searchRadius * 1000,
                      color: Styles.primaryColor.withOpacity(0.05),
                      borderColor: Styles.primaryColor.withOpacity(0.2),
                      borderStrokeWidth: 1,
                      useRadiusInMeter: true,
                    ),
                  ],
                ),
              if (_userLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _userLocation!,
                      width: 24,
                      height: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Styles.primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: _filteredProperties.asMap().entries.map((entry) {
                  final index = entry.key;
                  final property = entry.value;
                  final isSelected = index == _selectedPropertyIndex;
                  final color = _getPropertyColor(property.propertyTypeRaw);
                  final icon = _getPropertyIcon(property.propertyTypeRaw);
                  return Marker(
                    point: LatLng(property.latitude, property.longitude),
                    width: isSelected ? 50 : 40,
                    height: isSelected ? 50 : 40,
                    child: GestureDetector(
                      onTap: () {
                        Modular.to.pushNamed('/property/detail/${property.id}');
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: isSelected ? 4 : 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          icon,
                          color: Colors.white,
                          size: isSelected ? 24 : 20,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          MapDrawingDetector(
            isEnabled: _isDrawingMode,
            mapController: _mapController,
            onPolygonDrawn: (List<LatLng> polygon) {
              setState(() {
                _searchPolygon = polygon;
                _mapCenter = MapGeometryUtils.calculateCentroid(polygon);
                _isDrawingMode = false;
              });
              _mapController.move(_mapCenter, 14.5);
              _filterPropertiesByPolygon();
              final area = MapGeometryUtils.calculatePolygonArea(polygon);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '¡Área de búsqueda definida! (~${area.toStringAsFixed(1)} km²)',
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          _buildHeader(),
          _buildRadiusControl(),
          _buildFloatingButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.6), Colors.transparent],
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  height: 50,
                  width: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Modular.to.pushNamed('/worker/location-search'),
                    icon: const Icon(Icons.work_outline, size: 20),
                    label: const Text(
                      'Buscar Trabajadores',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Styles.primaryColor,
                      elevation: 4,
                      shadowColor: Colors.black.withOpacity(0.1),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadiusControl() {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Radio de búsqueda',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Styles.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_searchRadius.toStringAsFixed(1)} km',
                    style: TextStyle(
                      color: Styles.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Styles.primaryColor,
                inactiveTrackColor: Colors.grey[200],
                thumbColor: Styles.primaryColor,
                overlayColor: Styles.primaryColor.withOpacity(0.2),
                trackHeight: 4,
              ),
              child: Slider(
                value: _searchRadius,
                min: 1.0,
                max: 10.0,
                divisions: 18,
                onChanged: (value) {
                  setState(() {
                    _searchRadius = value;
                    _applyFilters();
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingButtons() {
    return Positioned(
      right: 16,
      bottom: 180,
      child: Column(
        children: [
          FloatingActionButton(
            heroTag: 'drawing_btn',
            backgroundColor: _isDrawingMode ? Colors.red : Colors.white,
            onPressed: () {
              setState(() {
                _isDrawingMode = !_isDrawingMode;
                if (_isDrawingMode) _searchPolygon = null;
              });
              if (_isDrawingMode) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Modo dibujo activado - Dibuja un área en el mapa',
                    ),
                    backgroundColor: Styles.primaryColor,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Image.asset(
              'assets/images/icon/hand-draw.png',
              width: 24,
              height: 24,
              color: _isDrawingMode ? Colors.white : Styles.primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'location_btn',
            backgroundColor: Colors.white,
            onPressed: _getCurrentLocation,
            child: _isLocating
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Styles.primaryColor,
                      ),
                    ),
                  )
                : Icon(Icons.my_location, color: Styles.primaryColor),
          ),
        ],
      ),
    );
  }
}
