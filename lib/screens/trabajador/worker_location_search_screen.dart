import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../theme/theme.dart';
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

        // Obtener ubicación del campo 'location'
        final location = data['location'] as Map<String, dynamic>?;
        if (location != null) {
          final latitude = (location['latitude'] as num?)?.toDouble();
          final longitude = (location['longitude'] as num?)?.toDouble();

          if (latitude != null && longitude != null) {
            workers.add(
              WorkerData(
                id: doc.id,
                name: data['name'] ?? 'Sin nombre',
                profession: data['profession'] ?? 'Profesional',
                category: data['category'] ?? 'Servicios',
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
      // Filtrar por categoría
      if (_selectedCategories.isNotEmpty &&
          !_selectedCategories.contains(worker.category)) {
        return false;
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
      // Filtrar por categoría
      if (_selectedCategories.isNotEmpty &&
          !_selectedCategories.contains(worker.category)) {
        return false;
      }

      // Verificar si el trabajador está dentro del polígono
      final workerLocation = LatLng(worker.latitude, worker.longitude);
      return MapGeometryUtils.isPointInPolygon(workerLocation, _searchPolygon!);
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
              initialZoom: 14.0,
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture) {
                  _mapCenter = camera.center;
                }
              },
              onTap: (_, __) {
                setState(() {
                  _selectedWorkerIndex = -1;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://api.mapbox.com/styles/v1/$_mapboxStyleId/tiles/256/{z}/{x}/{y}@2x?access_token=$_mapboxAccessToken',
                userAgentPackageName: 'com.mobiliaria.app',
              ),

              // Polígono de búsqueda dibujado
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

              // Radio de búsqueda
              if (_userLocation != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _userLocation!,
                      radius: _searchRadius * 1000,
                      color: Styles.primaryColor.withOpacity(0.08),
                      borderColor: Styles.primaryColor.withOpacity(0.3),
                      borderStrokeWidth: 1,
                      useRadiusInMeter: true,
                    ),
                  ],
                ),

              // Marcadores de trabajadores
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
                        Modular.to.pushNamed(
                          '/worker/public-profile',
                          arguments: worker,
                        );
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

              // Ubicación del Usuario
              if (_userLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _userLocation!,
                      width: 24,
                      height: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blueAccent,
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
                    Marker(
                      point: _userLocation!,
                      width: 60,
                      height: 60,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          // Detector de dibujo en el mapa
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

          // Barra superior con filtros
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
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
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Modular.to.pop(),
                        ),
                        const Expanded(
                          child: Text(
                            'Buscar trabajadores',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.filter_list),
                          onPressed: () {
                            // Mostrar opciones avanzadas de filtro
                          },
                        ),
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: _categoryStyles.keys.map((category) {
                        final isSelected = _selectedCategories.contains(
                          category,
                        );
                        final style = _categoryStyles[category]!;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  style['icon'],
                                  size: 16,
                                  color: isSelected
                                      ? Colors.white
                                      : style['color'],
                                ),
                                const SizedBox(width: 6),
                                Text(category),
                              ],
                            ),
                            selected: isSelected,
                            onSelected: (_) => _toggleCategory(category),
                            backgroundColor: Colors.white,
                            selectedColor: style['color'],
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected
                                    ? Colors.transparent
                                    : Colors.grey[300]!,
                              ),
                            ),
                            elevation: 2,
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

          // Botón de modo de dibujo
          Positioned(
            right: 16,
            bottom: 370,
            child: FloatingActionButton(
              heroTag: 'drawing_btn',
              backgroundColor: _isDrawingMode
                  ? const Color(0xFF0033CC)
                  : Colors.white,
              onPressed: () {
                setState(() {
                  _isDrawingMode = !_isDrawingMode;
                  // Limpiar el polígono anterior cuando se activa el modo de dibujo
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
                width: 30,
                height: 30,
                color: _isDrawingMode ? Colors.white : const Color(0xFF0033CC),
              ),
            ),
          ),

          // Botón de ubicación
          Positioned(
            right: 16,
            bottom: 300,
            child: FloatingActionButton(
              heroTag: 'location_btn',
              backgroundColor: Colors.white,
              onPressed: _isLocating ? null : _getCurrentLocation,
              child: _isLocating
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location, color: Colors.blueAccent),
            ),
          ),

          // Panel Inferior Fijo (Slider + Lista)
          DraggableScrollableSheet(
            initialChildSize: 0.35,
            minChildSize: 0.2,
            maxChildSize: 0.8,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Slider de Rango
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Rango',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                '${_searchRadius.toStringAsFixed(1)} Km',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
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
                              ).withOpacity(0.1),
                              trackHeight: 4,
                            ),
                            child: Slider(
                              value: _searchRadius,
                              min: 1,
                              max: 20,
                              divisions: 19,
                              onChanged: (value) {
                                if (value > 3.0) {
                                  showDialog(
                                    context: context,
                                    builder: (context) =>
                                        const PremiumSubscriptionModal(),
                                  );
                                  setState(() {
                                    _searchRadius = 3.0;
                                    _filterWorkersByLocation();
                                  });
                                } else {
                                  setState(() {
                                    _searchRadius = value;
                                    _filterWorkersByLocation();
                                  });
                                }
                              },
                            ),
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                _filterWorkersByLocation();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0033CC),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Iniciar búsqueda',
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

                    const SizedBox(height: 16),
                    const Divider(height: 1),

                    // Lista de resultados
                    if (_filteredWorkers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Center(
                          child: Text(
                            'No hay trabajadores en este rango',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredWorkers.length,
                        itemBuilder: (context, index) {
                          final worker = _filteredWorkers[index];
                          String distanceDisplay = '';

                          if (_userLocation != null) {
                            final distanceInMeters = Geolocator.distanceBetween(
                              _userLocation!.latitude,
                              _userLocation!.longitude,
                              worker.latitude,
                              worker.longitude,
                            );

                            if (distanceInMeters < 1000) {
                              distanceDisplay = '${distanceInMeters.toInt()} m';
                            } else {
                              final distanceKm = distanceInMeters / 1000;
                              distanceDisplay =
                                  '${distanceKm.toStringAsFixed(1)} km';
                            }
                          }

                          return _buildWorkerCard(worker, distanceDisplay);
                        },
                      ),
                  ],
                ),
              );
            },
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
                    children: const [
                      Text(
                        'Ver perfil completo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, color: Colors.white, size: 16),
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
  final String category;
  final double latitude;
  final double longitude;
  final String? photoUrl;
  final double rating;
  final String phone;
  final String price;

  WorkerData({
    required this.id,
    required this.name,
    required this.profession,
    required this.category,
    required this.latitude,
    required this.longitude,
    this.photoUrl,
    required this.rating,
    required this.phone,
    required this.price,
  });
}
