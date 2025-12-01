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
import 'premium_subscription_modal.dart';

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
  final Set<String> _selectedCategories = {};
  List<WorkerData> _workers = [];
  List<WorkerData> _filteredWorkers = [];

  // Controlador para el PageView de trabajadores
  late PageController _pageController;
  int _selectedWorkerIndex = -1;

  // Estado del modo de dibujo
  bool _isDrawingMode = false;
  List<LatLng>? _searchPolygon; // Polígono de búsqueda dibujado

  // Categorías disponibles con sus colores e iconos
  final Map<String, Map<String, dynamic>> _categoryStyles = {
    'Técnicos': {'color': Colors.orange, 'icon': Icons.build},
    'Mano de obra': {'color': Colors.green, 'icon': Icons.handyman},
    'Profesionales': {'color': Colors.purple, 'icon': Icons.work},
    'Servicios': {'color': Colors.blue, 'icon': Icons.cleaning_services},
  };

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
      // Filtrar por categoría (ahora soporta múltiples categorías)
      if (_selectedCategories.isNotEmpty) {
        bool hasMatchingCategory = false;
        for (var category in worker.categories) {
          if (_selectedCategories.contains(category)) {
            hasMatchingCategory = true;
            break;
          }
        }
        if (!hasMatchingCategory) return false;
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

    setState(() {
      _filteredWorkers = filtered;
    });
  }

  void _toggleCategory(String category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        _selectedCategories.add(category);
      }
      _filterWorkersByLocation();
    });
  }

  void _filterWorkersByPolygon() {
    if (_searchPolygon == null || _searchPolygon!.isEmpty) return;

    final filtered = _workers.where((worker) {
      // Filtrar por categoría (ahora soporta múltiples categorías)
      if (_selectedCategories.isNotEmpty) {
        bool hasMatchingCategory = false;
        for (var category in worker.categories) {
          if (_selectedCategories.contains(category)) {
            hasMatchingCategory = true;
            break;
          }
        }
        if (!hasMatchingCategory) return false;
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

    setState(() {
      _filteredWorkers = filtered;
    });
  }

  Future<void> _incrementWorkerViews(String workerId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(workerId).set({
        'views': FieldValue.increment(1),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error incrementing views: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Mapa
          FlutterMap(
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
                child: Column(
                  children: [
                    Row(
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
                            child: const Row(
                              children: [
                                Icon(Icons.search, color: Colors.grey),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Buscar servicios...',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          height: 50,
                          width: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0033CC),
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
                            icon: const Icon(Icons.tune, color: Colors.white),
                            onPressed: () {
                              // Mostrar modal de filtros avanzados
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _categoryStyles.entries.map((entry) {
                          final isSelected = _selectedCategories.contains(
                            entry.key,
                          );
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(entry.key),
                              selected: isSelected,
                              onSelected: (_) => _toggleCategory(entry.key),
                              backgroundColor: Colors.white,
                              selectedColor: const Color(0xFF0033CC),
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              avatar: Icon(
                                entry.value['icon'],
                                size: 18,
                                color: isSelected
                                    ? Colors.white
                                    : entry.value['color'],
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected
                                      ? Colors.transparent
                                      : Colors.grey[300]!,
                                ),
                              ),
                              showCheckmark: false,
                            ),
                          );
                        }).toList(),
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
                                        if (value > 3.0) {
                                          // Mostrar modal Premium si supera 3km
                                          showModalBottomSheet(
                                            context: context,
                                            isScrollControlled: true,
                                            backgroundColor: Colors.transparent,
                                            builder: (context) =>
                                                const PremiumSubscriptionModal(),
                                          );
                                          // Resetear a 3.0
                                          setState(() => _searchRadius = 3.0);
                                          _filterWorkersByLocation();
                                        } else {
                                          setState(() {
                                            _searchRadius = value;
                                            _filterWorkersByLocation();
                                          });
                                        }
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            _incrementWorkerViews(worker.id);
            Modular.to.pushNamed('/worker/public-profile', arguments: worker);
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
                              border: Border.all(color: Colors.white, width: 2),
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
                          Text(
                            worker.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF212121),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            worker.profession,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // Indicador de nivel (ej. Avanzado)
                              Row(
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 8,
                                    color: Colors.amber[700],
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    Icons.circle,
                                    size: 8,
                                    color: Colors.amber[700],
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    Icons.circle,
                                    size: 8,
                                    color: Colors.amber[700],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Avanzado',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
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
                                worker.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF212121),
                                ),
                              ),
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

                    // Precio (Derecha)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Desde',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          worker.price.isNotEmpty
                              ? 'Bs ${worker.price}'
                              : 'A convenir',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0033CC),
                          ),
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
  });

  // Getter para compatibilidad
  String get category => categories.isNotEmpty ? categories.first : 'Servicios';
}
