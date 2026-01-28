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
  double _searchRadius = 1.5;

  List<Property> _properties = [];
  List<Property> _filteredProperties = [];
  int _selectedPropertyIndex = -1;
  bool _isDrawingMode = false;
  List<LatLng>? _searchPolygon;
  final Set<String> _selectedPropertyTypes = {};
  bool _isCategoryPanelOpen = false;
  final TextEditingController _searchController = TextEditingController();

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

  // _transactionStyles removed (unused)

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
    _searchController.dispose();
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
      final withinRadius = (distance / 1000) <= _searchRadius;
      final matchesType =
          _selectedPropertyTypes.isEmpty ||
          _selectedPropertyTypes.contains(
            property.propertyTypeRaw.toLowerCase(),
          );

      final searchPrice = _searchController.text.toLowerCase();
      final matchesSearch =
          searchPrice.isEmpty ||
          property.name.toLowerCase().contains(searchPrice) ||
          property.location.toLowerCase().contains(searchPrice);

      return withinRadius && matchesType && matchesSearch;
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
      // Filtrar por categorías seleccionadas
      final matchesType =
          _selectedPropertyTypes.isEmpty ||
          _selectedPropertyTypes.contains(
            property.propertyTypeRaw.toLowerCase(),
          );
      if (!matchesType) return false;

      final searchPrice = _searchController.text.toLowerCase();
      final matchesSearch =
          searchPrice.isEmpty ||
          property.name.toLowerCase().contains(searchPrice) ||
          property.location.toLowerCase().contains(searchPrice);

      if (!matchesSearch) return false;

      final propertyLocation = LatLng(property.latitude, property.longitude);

      // Verificar si está dentro del polígono
      bool inPolygon = MapGeometryUtils.isPointInPolygon(
        propertyLocation,
        _searchPolygon!,
      );

      // Verificar si está dentro del radio desde la ubicación del usuario
      bool inRadius = false;
      if (_userLocation != null) {
        final distance = Geolocator.distanceBetween(
          _userLocation!.latitude,
          _userLocation!.longitude,
          property.latitude,
          property.longitude,
        );
        final distanceKm = distance / 1000;
        inRadius = distanceKm <= _searchRadius;
      }

      // Incluir si está en el polígono O dentro del radio
      return inPolygon || inRadius;
    }).toList();

    // Ordenar por distancia al centro del polígono
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
                      color: Styles.primaryColor.withAlpha(38),
                      borderColor: Styles.primaryColor,
                      borderStrokeWidth: 3.0,
                    ),
                  ],
                ),
              if (_userLocation != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _userLocation!,
                      radius: _searchRadius * 1000,
                      color: Styles.primaryColor.withAlpha(13),
                      borderColor: Styles.primaryColor.withAlpha(51),
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
                              color: Colors.black.withAlpha(51),
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
                              color: Colors.black.withAlpha(77),
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
          if (_isCategoryPanelOpen) _buildCategoryPanel(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.6), Colors.transparent],
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) => _applyFilters(),
                          decoration: InputDecoration(
                            hintText: _selectedPropertyTypes.isNotEmpty
                                ? '${_selectedPropertyTypes.length} filtros activos'
                                : 'Buscar por nombre o zona...',
                            hintStyle: TextStyle(
                              color: _selectedPropertyTypes.isNotEmpty
                                  ? Styles.primaryColor
                                  : Colors.grey,
                              fontSize: 15,
                            ),
                            border: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            filled: false,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                      if (_selectedPropertyTypes.isNotEmpty ||
                          _searchController.text.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              if (_searchController.text.isNotEmpty) {
                                _searchController.clear();
                              } else {
                                _selectedPropertyTypes.clear();
                              }
                              _applyFilters();
                            });
                          },
                          child: const Icon(
                            Icons.close,
                            color: Colors.grey,
                            size: 20,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Botón para abrir panel de categorías
              Stack(
                children: [
                  Container(
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      color: _isCategoryPanelOpen
                          ? Colors.white
                          : const Color(0xFF0033CC),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Styles.primaryColor.withAlpha(77),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.tune,
                        color: _isCategoryPanelOpen
                            ? const Color(0xFF0033CC)
                            : Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          _isCategoryPanelOpen = !_isCategoryPanelOpen;
                        });
                      },
                    ),
                  ),
                  if (_selectedPropertyTypes.isNotEmpty)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          '${_selectedPropertyTypes.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryPanel() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 70,
      right: 12,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.75 > 280
              ? 280
              : MediaQuery.of(context).size.width * 0.75,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.55,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header del panel
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: Styles.primaryColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isCategoryPanelOpen = false;
                        });
                      },
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Filtrar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (_selectedPropertyTypes.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedPropertyTypes.clear();
                          });
                          _applyFilters();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Limpiar',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),
              // Lista de categorías
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: _categoryStyles.entries.map((entry) {
                    final isSelected = _selectedPropertyTypes.contains(
                      entry.key,
                    );
                    // final color removed (unused)
                    return InkWell(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedPropertyTypes.remove(entry.key);
                          } else {
                            _selectedPropertyTypes.add(entry.key);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Styles.primaryColor.withAlpha(13)
                              : Colors.transparent,
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey[200]!,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              entry.value['icon'] as IconData,
                              size: 22,
                              color: isSelected
                                  ? Styles.primaryColor
                                  : Colors.grey[600],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                entry.value['label'] as String,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Styles.primaryColor
                                      : Colors.black87,
                                ),
                              ),
                            ),
                            if (isSelected)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Styles.primaryColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              // Botón Aplicar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(26),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isCategoryPanelOpen = false;
                        });
                        _applyFilters();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Styles.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _selectedPropertyTypes.isNotEmpty
                            ? 'Aplicar ${_selectedPropertyTypes.length} filtros'
                            : 'Aplicar Filtros',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Styles.primaryColor.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Styles.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.radar,
                    color: Styles.primaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Radio de búsqueda',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Styles.primaryColor,
                        Styles.primaryColor.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Styles.primaryColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '${_searchRadius.toStringAsFixed(1)} km',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Styles.primaryColor,
                inactiveTrackColor: Colors.grey[300],
                thumbColor: Colors.white,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                overlayColor: Styles.primaryColor.withOpacity(0.2),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
                trackHeight: 6,
                activeTickMarkColor: Colors.transparent,
                inactiveTickMarkColor: Colors.transparent,
              ),
              child: Slider(
                value: _searchRadius,
                min: 0.5,
                max: 10.0,
                divisions: 19,
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
