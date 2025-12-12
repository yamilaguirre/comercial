import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/map_drawing_detector.dart';
import '../../utils/map_geometry_utils.dart';
import '../../core/data/professions_data.dart';
import '../../services/location_service.dart';
import '../../services/profile_views_service.dart';

// Token de Mapbox
const String _mapboxAccessToken =
    'pk.eyJ1IjoibXVqZXJlc2Fsdm9sYW50ZSIsImEiOiJjbWFoZTR1ZzEwYXdvMmtxMHg5ZXZneXgyIn0.9aNpyQyi5wP1qKi0SjiR5Q';
const String _mapboxStyleId = 'mapbox/streets-v12';

class WorkerLocationSearchScreen extends StatefulWidget {
  const WorkerLocationSearchScreen({super.key});

  @override
  State<WorkerLocationSearchScreen> createState() =>
      _WorkerLocationSearchScreenState();
}

class _WorkerLocationSearchScreenState
    extends State<WorkerLocationSearchScreen> {
  late final MapController _mapController;
  LatLng _mapCenter = const LatLng(
    -17.3938,
    -66.1571,
  ); // Cochabamba por defecto
  LatLng? _userLocation; // Ubicación real del usuario
  bool _isLocating = false;
  double _searchRadius = 5.0; // Radio en kilómetros
  // Nuevo: Map para subcategorías seleccionadas (como en ProfessionSelector)
  final Map<String, List<String>> _selectedSubcategories = {};
  List<WorkerData> _workers = [];
  List<WorkerData> _filteredWorkers = [];

  // Controlador para el PageView de trabajadores
  late PageController _pageController;
  int _selectedWorkerIndex = -1;

  // Estado del modo de dibujo
  bool _isDrawingMode = false;
  List<LatLng>? _searchPolygon; // Polígono de búsqueda dibujado

  // Estado del panel de categorías
  bool _isCategoryPanelOpen = false;
  final Set<String> _expandedCategories = {};

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _pageController = PageController(viewportFraction: 0.9);
    _getCurrentLocation();
    _loadWorkers();
  }

  @override
  void dispose() {
    _pageController.dispose();
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
        _filterWorkersByLocation();
      }
    } catch (e) {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _loadWorkers() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUserId = authService.currentUser?.uid;

      // Fetch premium users to check isPremium status
      final premiumSnapshot = await FirebaseFirestore.instance
          .collection('premium_users')
          .get();
      final premiumUserIds = premiumSnapshot.docs.map((doc) => doc.id).toSet();

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'trabajo')
          .where('status', isEqualTo: 'trabajo')
          .get();

      final workers = <WorkerData>[];
      for (var doc in snapshot.docs) {
        // Excluir al usuario actual
        if (doc.id == currentUserId) continue;

        final data = doc.data();
        final profile = data['profile'] as Map<String, dynamic>?;

        // Verificar que tenga perfil completo de freelance (igual que home_work_screen)
        final hasProfessions =
            (data['professions'] as List<dynamic>?)?.isNotEmpty ?? false;
        final hasPortfolio =
            (profile?['portfolioImages'] as List<dynamic>?)?.isNotEmpty ??
            false;
        final hasDescription =
            (profile?['description'] as String?)?.isNotEmpty ?? false;

        // Solo mostrar trabajadores con perfil completo
        if (!hasProfessions || !hasPortfolio || !hasDescription) {
          continue;
        }

        // NUEVO: Verificar que el trabajador esté VERIFICADO
        final verificationStatus = data['verificationStatus'] as String?;
        if (verificationStatus != 'verified') {
          continue;
        }

        // Obtener ubicación del campo 'location'
        final location = data['location'] as Map<String, dynamic>?;
        if (location != null) {
          final latitude = (location['latitude'] as num?)?.toDouble();
          final longitude = (location['longitude'] as num?)?.toDouble();

          if (latitude != null && longitude != null) {
            // Extraer categorías de la lista de profesiones
            List<String> categories = [];
            final professions = data['professions'] as List<dynamic>?;

            if (professions != null && professions.isNotEmpty) {
              for (var p in professions) {
                if (p is Map<String, dynamic> && p['category'] != null) {
                  categories.add(p['category'].toString());
                }
              }
            }

            // Fallback si no hay profesiones o categorías
            if (categories.isEmpty) {
              final legacyCategory = data['category']?.toString();
              if (legacyCategory != null && legacyCategory.isNotEmpty) {
                categories.add(legacyCategory);
              } else {
                categories.add('Servicios');
              }
            }

            workers.add(
              WorkerData(
                id: doc.id,
                name: data['name'] ?? 'Sin nombre',
                profession: data['profession'] ?? 'Profesional',
                categories: categories,
                latitude: latitude,
                longitude: longitude,
                photoUrl: data['photoUrl'],
                rating: (data['rating'] ?? 0.0).toDouble(),
                phone: data['phone'] ?? '',
                price: (data['price']?.toString() ?? '').trim(),
                locationName: location['locationName'] as String?,
                isFixedLocation: location['isFixed'] as bool? ?? false,
                locationType: location['locationType'] as String?,
                isPremium: premiumUserIds.contains(doc.id),
                experienceLevel: (profile?['experienceLevel'] as String?) ?? 'Intermedio',
                currency: (profile?['currency'] as String?) ?? 'Bs',
              ),
            );
          }
        }
      }

      setState(() {
        _workers = workers;
        _filterWorkersByLocation();
      });
    } catch (e) {
      debugPrint('Error loading workers: $e');
    }
  }

  void _filterWorkersByLocation() {
    if (_userLocation == null) return;

    final filtered = _workers.where((worker) {
      // Filtrar por subcategorías seleccionadas
      if (_hasAnySubcategorySelected()) {
        bool hasMatchingSubcategory = _workerMatchesSelectedSubcategories(
          worker,
        );
        if (!hasMatchingSubcategory) return false;
      }

      // Filtrar por distancia desde la ubicación del usuario
      final distance = Geolocator.distanceBetween(
        _userLocation!.latitude,
        _userLocation!.longitude,
        worker.latitude,
        worker.longitude,
      );
      final distanceKm = distance / 1000;
      return distanceKm <= _searchRadius;
    }).toList();

    // Ordenar por distancia
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

    // Sort premium workers first, then by distance
    filtered.sort((a, b) {
      // First priority: premium status (premium first)
      if (a.isPremium && !b.isPremium) return -1;
      if (!a.isPremium && b.isPremium) return 1;

      // Second priority: distance (closer first)
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

    setState(() {
      _filteredWorkers = filtered;
    });
  }

  // Verifica si hay alguna subcategoría seleccionada
  bool _hasAnySubcategorySelected() {
    for (var subs in _selectedSubcategories.values) {
      if (subs.isNotEmpty) return true;
    }
    return false;
  }

  // Verifica si el trabajador coincide con alguna subcategoría seleccionada
  bool _workerMatchesSelectedSubcategories(WorkerData worker) {
    // Recorrer todas las subcategorías seleccionadas
    for (var entry in _selectedSubcategories.entries) {
      final selectedSubs = entry.value;
      if (selectedSubs.isEmpty) continue;

      // Verificar si el trabajador tiene esta subcategoría en su perfil
      // (comparando contra worker.profession o worker.categories)
      for (var sub in selectedSubs) {
        if (worker.profession.toLowerCase().contains(sub.toLowerCase())) {
          return true;
        }
        // También verificar en las categorías (que contienen subcategorías cargadas)
        for (var cat in worker.categories) {
          if (cat.toLowerCase().contains(sub.toLowerCase()) ||
              sub.toLowerCase().contains(cat.toLowerCase())) {
            return true;
          }
        }
      }
    }
    return false;
  }

  // Cuenta el total de subcategorías seleccionadas
  int _getSelectedSubcategoriesCount() {
    int count = 0;
    for (var subs in _selectedSubcategories.values) {
      count += subs.length;
    }
    return count;
  }

  // Toggle de subcategoría (compatible con ProfessionSelector)
  void _toggleSubcategory(String category, String subcategory) {
    setState(() {
      if (!_selectedSubcategories.containsKey(category)) {
        _selectedSubcategories[category] = [];
      }

      final list = _selectedSubcategories[category]!;
      if (list.contains(subcategory)) {
        list.remove(subcategory);
      } else {
        list.add(subcategory);
      }

      // Limpiar si está vacía
      if (list.isEmpty) {
        _selectedSubcategories.remove(category);
      }
    });
  }

  // Limpia todas las selecciones
  void _clearAllSelections() {
    setState(() {
      _selectedSubcategories.clear();
    });
  }

  // Toggle de expansión de categoría
  void _toggleCategoryExpansion(String category) {
    setState(() {
      if (_expandedCategories.contains(category)) {
        _expandedCategories.remove(category);
      } else {
        _expandedCategories.add(category);
      }
    });
  }

  // Obtener icono para cada categoría
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Mano de obra':
        return Icons.construction;
      case 'Técnicos':
        return Icons.build;
      case 'Profesionales':
        return Icons.work;
      case 'Otros':
        return Icons.more_horiz;
      default:
        return Icons.category;
    }
  }

  void _filterWorkersByPolygon() {
    if (_searchPolygon == null || _searchPolygon!.isEmpty) return;

    final filtered = _workers.where((worker) {
      // Filtrar por subcategorías seleccionadas
      if (_hasAnySubcategorySelected()) {
        bool hasMatchingSubcategory = _workerMatchesSelectedSubcategories(
          worker,
        );
        if (!hasMatchingSubcategory) return false;
      }

      final workerLocation = LatLng(worker.latitude, worker.longitude);

      // Verificar si está dentro del polígono
      bool inPolygon = MapGeometryUtils.isPointInPolygon(
        workerLocation,
        _searchPolygon!,
      );

      // Verificar si está dentro del radio desde la ubicación del usuario
      bool inRadius = false;
      if (_userLocation != null) {
        final distance = Geolocator.distanceBetween(
          _userLocation!.latitude,
          _userLocation!.longitude,
          worker.latitude,
          worker.longitude,
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

    // Sort premium workers first, then by distance
    filtered.sort((a, b) {
      // First priority: premium status (premium first)
      if (a.isPremium && !b.isPremium) return -1;
      if (!a.isPremium && b.isPremium) return 1;

      // Second priority: distance from polygon center
      final distanceA = Distance().as(
        LengthUnit.Meter,
        center,
        LatLng(a.latitude, a.longitude),
      );
      final distanceB = Distance().as(
        LengthUnit.Meter,
        center,
        LatLng(b.latitude, b.longitude),
      );
      return distanceA.compareTo(distanceB);
    });

    setState(() {
      _filteredWorkers = filtered;
    });
  }

  Future<void> _incrementWorkerViews(String workerId) async {
    // Obtener el usuario actual que está viendo el perfil
    final authService = Provider.of<AuthService>(context, listen: false);
    final viewerId = authService.currentUser?.uid;

    print('🔍 [VIEWS-MAP] Intentando registrar vista - Viewer: $viewerId, Worker: $workerId');

    if (viewerId == null) {
      print('⚠️ [VIEWS-MAP] No hay usuario logueado, no se registra vista');
      return;
    }

    if (viewerId == workerId) {
      print('⚠️ [VIEWS-MAP] Usuario viendo su propio perfil, no se registra vista');
      return;
    }

    try {
      print('📝 [VIEWS-MAP] Registrando vista en ProfileViewsService...');
      await ProfileViewsService.registerProfileView(
        workerId: workerId,
        viewerId: viewerId,
      );
      print('✅ [VIEWS-MAP] Vista registrada exitosamente');
    } catch (e) {
      print('❌ [VIEWS-MAP] Error registrando vista de perfil: $e');
      debugPrint('Error registrando vista de perfil: $e');
    }
  }

  // Helper para obtener color según nivel de experiencia
  Color _getLevelColor(String level) {
    switch (level) {
      case 'Básico':
        return const Color(0xFF2196F3); // Azul
      case 'Intermedio':
        return const Color(0xFFFF9800); // Naranja
      case 'Avanzado':
        return const Color(0xFF4CAF50); // Verde
      default:
        return const Color(0xFF9E9E9E); // Gris
    }
  }

  // Helper para obtener icono según nivel de experiencia
  IconData _getLevelIcon(String level) {
    switch (level) {
      case 'Básico':
        return Icons.star_border;
      case 'Intermedio':
        return Icons.star_half;
      case 'Avanzado':
        return Icons.star;
      default:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Mapa con padding para el status bar
          Padding(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _mapCenter,
                initialZoom: 14.5,
                onPositionChanged: (position, hasGesture) {
                  if (hasGesture) {
                    setState(() => _isLocating = false);
                  }
                },
                onTap: (_, __) {
                  if (_selectedWorkerIndex != -1) {
                    setState(() => _selectedWorkerIndex = -1);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://api.mapbox.com/styles/v1/$_mapboxStyleId/tiles/256/{z}/{x}/{y}@2x?access_token=$_mapboxAccessToken',
                  userAgentPackageName: 'com.mobiliaria.app',
                ),

                if (_searchPolygon != null && _searchPolygon!.isNotEmpty)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: _searchPolygon!,
                        color: const Color(0xFF0033CC).withOpacity(0.15),
                        borderColor: const Color(0xFF0033CC),
                        borderStrokeWidth: 3.0,
                        isFilled: true,
                      ),
                    ],
                  ),

                // Círculo de radio de búsqueda (Usuario)
                if (_userLocation != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: _userLocation!,
                        radius: _searchRadius * 1000,
                        color: const Color(0xFF0033CC).withOpacity(0.05),
                        borderColor: const Color(0xFF0033CC).withOpacity(0.2),
                        borderStrokeWidth: 1,
                        useRadiusInMeter: true,
                      ),
                    ],
                  ),

                // Marcador de ubicación del usuario
                if (_userLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _userLocation!,
                        width: 24,
                        height: 24,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF0033CC),
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
                  markers: _filteredWorkers.asMap().entries.map((entry) {
                    final index = entry.key;
                    final worker = entry.value;
                    final isSelected = index == _selectedWorkerIndex;

                    return Marker(
                      point: LatLng(worker.latitude, worker.longitude),
                      width: isSelected ? 70 : 55,
                      height: isSelected ? 70 : 55,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedWorkerIndex = index);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF0033CC),
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
                          child: ClipOval(
                            child:
                                worker.photoUrl != null &&
                                    worker.photoUrl!.isNotEmpty
                                ? Image.network(
                                    worker.photoUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: const Color(0xFF0033CC),
                                        child: Icon(
                                          Icons.person,
                                          color: Colors.white,
                                          size: isSelected ? 35 : 28,
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    color: const Color(0xFF0033CC),
                                    child: Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: isSelected ? 35 : 28,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
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
              _filterWorkersByPolygon();

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

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  16,
                  MediaQuery.of(context).size.height * 0.01,
                  16,
                  16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
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
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _hasAnySubcategorySelected()
                                    ? '${_getSelectedSubcategoriesCount()} filtros activos'
                                    : 'Buscar servicios...',
                                style: TextStyle(
                                  color: _hasAnySubcategorySelected()
                                      ? const Color(0xFF0033CC)
                                      : Colors.grey,
                                  fontSize: 16,
                                  fontWeight: _hasAnySubcategorySelected()
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (_hasAnySubcategorySelected())
                              GestureDetector(
                                onTap: () {
                                  _clearAllSelections();
                                  _filterWorkersByLocation();
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
                                color: const Color(0xFF0033CC).withOpacity(0.3),
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
                        // Badge de cantidad
                        if (_getSelectedSubcategoriesCount() > 0)
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
                                '${_getSelectedSubcategoriesCount()}',
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
          ),

          // Panel lateral de categorías (compacto y flotante)
          if (_isCategoryPanelOpen)
            Positioned(
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
                      // Header del panel (más compacto)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        decoration: const BoxDecoration(
                          color: Color(0xFF0033CC),
                          borderRadius: BorderRadius.vertical(
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
                            if (_hasAnySubcategorySelected())
                              TextButton(
                                onPressed: () {
                                  _clearAllSelections();
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Limpiar',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Lista de categorías (scrollable con Flexible)
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: professionsData.length,
                          itemBuilder: (context, index) {
                            final category = professionsData[index];
                            final isExpanded = _expandedCategories.contains(
                              category.category,
                            );
                            final selectedCount =
                                _selectedSubcategories[category.category]
                                    ?.length ??
                                0;

                            return Column(
                              children: [
                                // Categoría principal (expandible)
                                InkWell(
                                  onTap: () => _toggleCategoryExpansion(
                                    category.category,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selectedCount > 0
                                          ? const Color(
                                              0xFF0033CC,
                                            ).withOpacity(0.05)
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
                                          _getCategoryIcon(category.category),
                                          size: 22,
                                          color: selectedCount > 0
                                              ? const Color(0xFF0033CC)
                                              : Colors.grey[600],
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            category.category,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: selectedCount > 0
                                                  ? FontWeight.bold
                                                  : FontWeight.w500,
                                              color: selectedCount > 0
                                                  ? const Color(0xFF0033CC)
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ),
                                        if (selectedCount > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0033CC),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '$selectedCount',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          isExpanded
                                              ? Icons.keyboard_arrow_up
                                              : Icons.keyboard_arrow_down,
                                          color: Colors.grey[500],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Subcategorías (si está expandido)
                                if (isExpanded)
                                  Container(
                                    color: Colors.grey[50],
                                    child: Column(
                                      children: category.subcategories.map((
                                        subcategory,
                                      ) {
                                        final isSelected =
                                            (_selectedSubcategories[category
                                                        .category] ??
                                                    [])
                                                .contains(subcategory);
                                        return InkWell(
                                          onTap: () {
                                            _toggleSubcategory(
                                              category.category,
                                              subcategory,
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                            child: Row(
                                              children: [
                                                const SizedBox(width: 34),
                                                Container(
                                                  width: 22,
                                                  height: 22,
                                                  decoration: BoxDecoration(
                                                    color: isSelected
                                                        ? const Color(
                                                            0xFF0033CC,
                                                          )
                                                        : Colors.transparent,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                    border: Border.all(
                                                      color: isSelected
                                                          ? const Color(
                                                              0xFF0033CC,
                                                            )
                                                          : Colors.grey[400]!,
                                                      width: 2,
                                                    ),
                                                  ),
                                                  child: isSelected
                                                      ? const Icon(
                                                          Icons.check,
                                                          size: 16,
                                                          color: Colors.white,
                                                        )
                                                      : null,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    subcategory,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: isSelected
                                                          ? const Color(
                                                              0xFF0033CC,
                                                            )
                                                          : Colors.grey[700],
                                                      fontWeight: isSelected
                                                          ? FontWeight.w500
                                                          : FontWeight.normal,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                      // Botón Aplicar
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
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
                                _filterWorkersByLocation();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0033CC),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                _hasAnySubcategorySelected()
                                    ? 'Aplicar ${_getSelectedSubcategoriesCount()} filtros'
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
            ),

          // Panel deslizable con lista de trabajadores
          DraggableScrollableSheet(
            initialChildSize: 0.3,
            minChildSize: 0.15,
            maxChildSize: 0.75,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      controller: scrollController,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Barra de arrastre
                            Center(
                              child: Container(
                                margin: const EdgeInsets.only(
                                  top: 12,
                                  bottom: 8,
                                ),
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),

                            // Slider de radio
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 8,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Radio de búsqueda',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF0033CC,
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          '${_searchRadius.toStringAsFixed(1)} km',
                                          style: const TextStyle(
                                            color: Color(0xFF0033CC),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: const Color(0xFF0033CC),
                                      inactiveTrackColor: Colors.grey[200],
                                      thumbColor: const Color(0xFF0033CC),
                                      overlayColor: const Color(
                                        0xFF0033CC,
                                      ).withOpacity(0.2),
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
                                          _filterWorkersByLocation();
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const Divider(),

                            // Lista de trabajadores
                            _filteredWorkers.isEmpty
                                ? SizedBox(
                                    height: constraints.maxHeight * 0.5,
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.search_off,
                                            size: 64,
                                            color: Colors.grey[300],
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'No hay trabajadores cerca',
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _filteredWorkers.length,
                                    itemBuilder: (context, index) {
                                      final worker = _filteredWorkers[index];
                                      String distanceDisplay = '';
                                      if (_userLocation != null) {
                                        final d = Geolocator.distanceBetween(
                                          _userLocation!.latitude,
                                          _userLocation!.longitude,
                                          worker.latitude,
                                          worker.longitude,
                                        );
                                        distanceDisplay = d < 1000
                                            ? '${d.toInt()} m'
                                            : '${(d / 1000).toStringAsFixed(1)} km';
                                      }
                                      return _buildWorkerCard(
                                        worker,
                                        distanceDisplay,
                                      );
                                    },
                                  ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),

          // Botones flotantes (Dibujo y Ubicación)
          Positioned(
            right: 16,
            bottom: MediaQuery.of(context).size.height * 0.35,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'drawing_btn',
                  backgroundColor: _isDrawingMode ? Colors.red : Colors.white,
                  onPressed: () {
                    setState(() {
                      _isDrawingMode = !_isDrawingMode;
                      if (_isDrawingMode) {
                        _searchPolygon = null;
                      }
                    });
                    if (_isDrawingMode) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Modo dibujo activado - Dibuja un área en el mapa',
                          ),
                          backgroundColor: Color(0xFF0033CC),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: Image.asset(
                    'assets/images/icon/hand-draw.png',
                    width: 24,
                    height: 24,
                    color: _isDrawingMode
                        ? Colors.white
                        : const Color(0xFF0033CC),
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
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerCard(WorkerData worker, String distance) {
    // Use StreamBuilder to get real-time rating from feedback
    return StreamBuilder<Map<String, dynamic>>(
      stream: LocationService.calculateWorkerRatingStream(worker.id),
      builder: (context, ratingSnapshot) {
        final ratingData = ratingSnapshot.data ?? {'rating': 0.0, 'reviews': 0};
        final rating = (ratingData['rating'] as num?)?.toDouble() ?? 0.0;
        final reviews = (ratingData['reviews'] as num?)?.toInt() ?? 0;
        final isPremium = worker.isPremium;

        // Premium gradient wrapper
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: isPremium
                ? const LinearGradient(
                    colors: [
                      Color(0xFFFF6F00), // Vibrant Orange
                      Color(0xFFFFC107), // Vibrant Yellow
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: isPremium
                    ? const Color(0xFFFF6F00).withOpacity(0.3)
                    : Colors.black.withOpacity(0.08),
                blurRadius: isPremium ? 12 : 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Container(
            margin: isPremium ? const EdgeInsets.all(3) : EdgeInsets.zero,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isPremium ? 17 : 20),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(isPremium ? 17 : 20),
                onTap: () {
                  _incrementWorkerViews(worker.id);
                  Modular.to.pushNamed(
                    '/worker/public-profile',
                    arguments: worker,
                  );
                },
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Foto con indicador de estado
                          Stack(
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  image: worker.photoUrl != null
                                      ? DecorationImage(
                                          image: NetworkImage(worker.photoUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                  color: Colors.grey[200],
                                ),
                                child: worker.photoUrl == null
                                    ? Icon(
                                        Icons.person,
                                        size: 35,
                                        color: Colors.grey[400],
                                      )
                                    : null,
                              ),
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),

                          // Info Central
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Nombre (línea separada para evitar overflow)
                                Text(
                                  worker.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF212121),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                // Ubicación (línea separada si existe)
                                if (worker.locationName != null &&
                                    worker.locationName!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(
                                        worker.locationType == 'home'
                                            ? Icons.home
                                            : Icons.store,
                                        size: 12,
                                        color: const Color(0xFF0033CC),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          worker.locationName!,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF0033CC),
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  worker.profession,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    // Badge de nivel de experiencia (más compacto)
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getLevelColor(worker.experienceLevel).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: _getLevelColor(worker.experienceLevel),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _getLevelIcon(worker.experienceLevel),
                                              size: 10,
                                              color: _getLevelColor(worker.experienceLevel),
                                            ),
                                            const SizedBox(width: 3),
                                            Flexible(
                                              child: Text(
                                                worker.experienceLevel,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: _getLevelColor(worker.experienceLevel),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      size: 16,
                                      color: Colors.amber,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      rating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF212121),
                                      ),
                                    ),
                                    // Show reviews count if available
                                    if (reviews > 0) ...[
                                      Text(
                                        ' ($reviews)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                    const SizedBox(width: 12),
                                    const Icon(
                                      Icons.location_on_outlined,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      distance,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Precio (Derecha) - Más compacto
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Desde',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                worker.price.isNotEmpty
                                    ? '${worker.currency} ${worker.price}'
                                    : 'Convenir',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0033CC),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Botón inferior
                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0033CC),
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(20),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Ver perfil completo',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward,
                              color: Colors.white,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class WorkerData {
  final String id;
  final String name;
  final String profession;
  final List<String> categories;
  final double latitude;
  final double longitude;
  final String? photoUrl;
  final double rating;
  final String phone;
  final String price;
  final String verificationStatus;
  final String? locationName;
  final bool isFixedLocation;
  final String? locationType;
  final bool isPremium;
  final String experienceLevel;
  final String currency;

  WorkerData({
    required this.id,
    required this.name,
    required this.profession,
    required this.categories,
    required this.latitude,
    required this.longitude,
    this.photoUrl,
    required this.rating,
    required this.phone,
    required this.price,
    this.verificationStatus = 'unverified',
    this.locationName,
    this.isFixedLocation = false,
    this.locationType,
    this.isPremium = false,
    this.experienceLevel = 'Intermedio',
    this.currency = 'Bs',
  });

  // Getter para compatibilidad
  String get category => categories.isNotEmpty ? categories.first : 'Servicios';
}
