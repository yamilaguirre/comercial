import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/theme.dart';
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
        desiredAccuracy: LocationAccuracy.high,
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
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'trabajo')
          .where('status', isEqualTo: 'trabajo')
          .get();

      final workers = <WorkerData>[];
      for (var doc in snapshot.docs) {
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

      // Filtrar por distancia desde la ubicación del usuario (o centro del mapa si se prefiere)
      // Usamos _userLocation para filtrar lo que está cerca del usuario realmente
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

  void _onWorkerSelected(int index) {
    setState(() {
      _selectedWorkerIndex = index;
    });
    final worker = _filteredWorkers[index];
    _mapController.move(LatLng(worker.latitude, worker.longitude), 16.0);
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
                  // Solo actualizamos el centro visual, no la ubicación del usuario
                  _mapCenter = camera.center;
                }
              },
              onTap: (_, __) {
                // Deseleccionar trabajador al tocar el mapa
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

              // Radio de búsqueda (alrededor del usuario)
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

              // Marcadores de trabajadores con fotos de perfil
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
                        // Navegar al perfil público del trabajador
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

              // Marcador de Ubicación del Usuario (Punto Azul)
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
                    // Halo semitransparente alrededor
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

          // Barra superior con filtros
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Column(
                children: [
                  // App Bar flotante
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

                  // Chips de categorías
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

          // Botón de ubicación
          Positioned(
            right: 16,
            bottom: 300, // Ajustado para dejar espacio al panel inferior
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
                child: Column(
                  children: [
                    // Handle
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
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
                                  // Mostrar modal Premium si intenta pasar de 3km
                                  showDialog(
                                    context: context,
                                    builder: (context) =>
                                        const PremiumSubscriptionModal(),
                                  );
                                  // Mantener en 3km si no es premium
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
                    Expanded(
                      child: _filteredWorkers.isEmpty
                          ? Center(
                              child: Text(
                                'No hay trabajadores en este rango',
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredWorkers.length,
                              itemBuilder: (context, index) {
                                final worker = _filteredWorkers[index];
                                final distance = _userLocation != null
                                    ? Geolocator.distanceBetween(
                                            _userLocation!.latitude,
                                            _userLocation!.longitude,
                                            worker.latitude,
                                            worker.longitude,
                                          ) /
                                          1000
                                    : 0.0;
                                return _buildWorkerCard(worker, distance);
                              },
                            ),
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

  Widget _buildWorkerCard(WorkerData worker, double distance) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Navegar al perfil público
            Modular.to.pushNamed('/worker/public-profile', arguments: worker);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Foto con indicador de estado
                Stack(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
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
                              size: 30,
                              color: Colors.grey[400],
                            )
                          : null,
                    ),
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 14,
                        height: 14,
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

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              worker.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Desde',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                'Bs 120', // Placeholder o dato real
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0033CC),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        worker.profession,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            'Avanzado',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            worker.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${distance.toStringAsFixed(1)} km',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Modular.to.pushNamed(
                              '/worker/public-profile',
                              arguments: worker,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0033CC),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Ver perfil completo'),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward, size: 14),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Modelo de datos para trabajador
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
  });
}
