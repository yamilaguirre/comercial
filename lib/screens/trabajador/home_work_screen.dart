import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';

import 'package:flutter_modular/flutter_modular.dart'
    hide ModularWatchExtension;

import '../../theme/theme.dart';
import '../../providers/auth_provider.dart';

import '../../services/location_service.dart';
import 'worker_location_search_screen.dart';

import 'components/add_to_worker_collection_dialog.dart';

class HomeWorkScreen extends StatefulWidget {
  const HomeWorkScreen({super.key});

  @override
  State<HomeWorkScreen> createState() => _HomeWorkScreenState();
}

class _HomeWorkScreenState extends State<HomeWorkScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _locationInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeWorkerLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    LocationService().stopLocationTracking();
    super.dispose();
  }

  Future<void> _initializeWorkerLocation() async {
    final authService = context.read<AuthService>();
    final currentUser = authService.currentUser;

    if (currentUser != null && !_locationInitialized) {
      _locationInitialized = true;
      await LocationService.initializeWorkerProfile(currentUser.uid);
      final locationService = LocationService();
      final started = await locationService.startLocationTracking(
        currentUser.uid,
      );

      if (!started && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo obtener tu ubicación. Verifica los permisos.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
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

  Future<void> _toggleFavorite(String workerId, bool isFavorite) async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) return;

    try {
      if (isFavorite) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'favoriteWorkers': FieldValue.arrayRemove([workerId]),
            });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Eliminado de favoritos')),
          );
        }
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'favoriteWorkers': FieldValue.arrayUnion([workerId]),
            });
        if (mounted) {
          await showDialog(
            context: context,
            builder: (context) =>
                AddToWorkerCollectionDialog(workerId: workerId),
          );
        }
      }
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _buildLocationButton(),
                      const SizedBox(height: 24),
                      const Text(
                        'Destacados cerca de ti',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF212121),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildWorkersList(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo
          Image.asset('assets/images/logoColor.png', height: 50),
          const SizedBox(height: 16),

          // Barra de búsqueda
          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
            decoration: InputDecoration(
              hintText: '¿Qué servicio necesitas? (electricista, abogado...)',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Styles.primaryColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const WorkerLocationSearchScreen(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Buscar por ubicación',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Encuentra trabajadores cerca de ti',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
                const Icon(Icons.arrow_forward, color: Colors.white, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkersList() {
    final authService = context.watch<AuthService>();
    final currentUserId = authService.currentUser?.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          // No filtramos por rol/status para que aparezcan trabajadores
          // que estén navegando en el módulo inmobiliaria.
          // El filtrado real se hace abajo verificando el perfil completo.
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final workers = snapshot.data?.docs ?? [];

        if (workers.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(Icons.work_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No hay trabajadores disponibles aún',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }

        // Filtrar por búsqueda, excluir al usuario actual Y verificar perfil completo
        final filteredWorkers = workers.where((doc) {
          // Excluir al usuario actual
          if (doc.id == currentUserId) return false;

          final data = doc.data() as Map<String, dynamic>;
          final profile = data['profile'] as Map<String, dynamic>?;

          // Verificar que tenga datos básicos para evitar perfiles vacíos/invisibles
          final name = data['name'] as String?;
          if (name == null || name.isEmpty || name.trim().isEmpty) {
            return false;
          }

          // Verificar que tenga al menos una profesión
          final hasProfessions =
              (data['professions'] as List<dynamic>?)?.isNotEmpty ?? false;
          final topLevelProfession = data['profession'] as String?;
          final profileProfession = profile?['profession'] as String?;

          if (!hasProfessions &&
              (topLevelProfession == null || topLevelProfession.isEmpty) &&
              (profileProfession == null || profileProfession.isEmpty)) {
            return false;
          }

          // Filtrar por búsqueda
          final searchName = name.toLowerCase();
          // Prefer top-level `profession` if exists; otherwise, check `profile.profession` or arrays
          String profession =
              (data['profession'] ?? profile?['profession'] ?? '')
                  .toString()
                  .toLowerCase();
          final professionsData =
              (data['professions'] as List<dynamic>?) ??
              (profile?['professions'] as List<dynamic>?);
          if ((profession.isEmpty ||
                  profession == 'sin profesión especificada') &&
              professionsData != null &&
              professionsData.isNotEmpty) {
            final List<String> allSubcategories = [];
            for (var prof in professionsData) {
              final profMap = prof as Map<String, dynamic>?;
              final subcategories = profMap?['subcategories'] as List<dynamic>?;
              if (subcategories != null && subcategories.isNotEmpty) {
                allSubcategories.addAll(
                  subcategories.map((s) => s.toString().toLowerCase()),
                );
              } else {
                final cat = profMap?['category'] as String? ?? '';
                if (cat.isNotEmpty) allSubcategories.add(cat.toLowerCase());
              }
            }
            if (allSubcategories.isNotEmpty) {
              profession = allSubcategories.join(' ');
            }
          }

          final services =
              (data['services'] as List<dynamic>?)
                  ?.map((s) => s.toString().toLowerCase())
                  .toList() ??
              [];

          return searchName.contains(_searchQuery) ||
              profession.contains(_searchQuery) ||
              services.any((s) => s.contains(_searchQuery));
        }).toList();

        if (filteredWorkers.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                'No se encontraron trabajadores para "$_searchQuery"',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return StreamBuilder<Position>(
          stream: Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 50,
            ),
          ),
          builder: (context, locationSnapshot) {
            final userLocation =
                locationSnapshot.data ?? LocationService().lastPosition;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.62,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: filteredWorkers.length,
              itemBuilder: (context, index) {
                final workerDoc = filteredWorkers[index];
                final data = workerDoc.data() as Map<String, dynamic>;

                // Solo mostrar si tiene los datos básicos necesarios
                final name = data['name'] as String?;
                if (name == null || name.isEmpty) {
                  return const SizedBox.shrink();
                }

                // Calcular distancia real si ambos tienen ubicación
                String distance = '';
                final workerLocation =
                    data['location'] as Map<String, dynamic>?;

                // Verificar si debe mostrarse en el mapa (para decidir si mostrar distancia)
                final locationSettings =
                    data['locationSettings'] as Map<String, dynamic>?;
                final showOnMap =
                    locationSettings?['showOnMap'] as bool? ?? true;

                if (workerLocation != null &&
                    userLocation != null &&
                    showOnMap) {
                  final workerLat = (workerLocation['latitude'] as num?)
                      ?.toDouble();
                  final workerLng = (workerLocation['longitude'] as num?)
                      ?.toDouble();

                  if (workerLat != null && workerLng != null) {
                    final distanceInMeters = Geolocator.distanceBetween(
                      userLocation.latitude,
                      userLocation.longitude,
                      workerLat,
                      workerLng,
                    );
                    final distanceKm = distanceInMeters / 1000;

                    if (distanceKm < 1) {
                      distance = '${distanceInMeters.toInt()}m';
                    } else {
                      distance = '${distanceKm.toStringAsFixed(1)} km';
                    }
                  }
                }

                // Extraer profesión (primero revisar top-level `profession`, luego `profile.profession`, luego `professions` arrays)
                final profileMap = data['profile'] as Map<String, dynamic>?;
                String profession =
                    (data['profession'] as String? ??
                            profileMap?['profession'] as String? ??
                            '')
                        .toString();
                final professionsData =
                    (data['professions'] as List<dynamic>?) ??
                    (profileMap?['professions'] as List<dynamic>?);
                if (profession.isEmpty) {
                  profession = 'Sin profesión especificada';
                }
                if (professionsData != null && professionsData.isNotEmpty) {
                  // Recolectar todas las subcategorías de todas las profesiones
                  final List<String> allSubcategories = [];

                  for (var prof in professionsData) {
                    final profMap = prof as Map<String, dynamic>?;
                    final subcategories =
                        profMap?['subcategories'] as List<dynamic>?;

                    if (subcategories != null && subcategories.isNotEmpty) {
                      allSubcategories.addAll(
                        subcategories.map((s) => s.toString()),
                      );
                    }
                  }

                  // Si top-level profession está vacío o es el valor por defecto,
                  // usar el array de profesiones para construir la visualización
                  if (profession == 'Sin profesión especificada') {
                    if (allSubcategories.isNotEmpty) {
                      profession = allSubcategories.take(2).join(' • ');
                    } else {
                      // Si no tiene subcategorías, usar la categoría principal
                      final firstProfession =
                          professionsData[0] as Map<String, dynamic>?;
                      final category =
                          firstProfession?['category'] as String? ?? '';
                      if (category.isNotEmpty) {
                        profession = category;
                      }
                    }
                  } else {
                    // top-level profession is already set; keep it
                  }
                }

                return StreamBuilder<Map<String, dynamic>>(
                  stream: LocationService.calculateWorkerRatingStream(
                    workerDoc.id,
                  ),
                  builder: (context, ratingSnapshot) {
                    final ratingData =
                        ratingSnapshot.data ?? {'rating': 0.0, 'reviews': 0};

                    return _buildCompactWorkerCard(
                      workerId: workerDoc.id,
                      name: name,
                      profession: profession,
                      rating: (ratingData['rating'] as num).toDouble(),
                      reviews: ratingData['reviews'] as int,
                      price: (data['price']?.toString() ?? '').trim(),
                      distance: distance,
                      photoUrl: data['photoUrl'] as String?,
                      phone: data['phoneNumber'] as String? ?? '',
                      latitude: workerLocation?['latitude'] as double? ?? 0.0,
                      longitude: workerLocation?['longitude'] as double? ?? 0.0,
                      categories:
                          professionsData
                              ?.map(
                                (p) =>
                                    (p as Map<String, dynamic>?)?['category']
                                        ?.toString() ??
                                    '',
                              )
                              .where((c) => c.isNotEmpty)
                              .toList() ??
                          ['Servicios'],
                      workerLocation: workerLocation,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCompactWorkerCard({
    required String workerId,
    required String name,
    required String profession,
    required double rating,
    required int reviews,
    required String price,
    required String distance,
    String? photoUrl,
    required String phone,
    required double latitude,
    required double longitude,
    required List<String> categories,
    Map<String, dynamic>? workerLocation,
  }) {
    final authService = context.read<AuthService>();
    final currentUserId = authService.currentUser?.uid ?? '';

    return GestureDetector(
      onTap: () {
        _incrementWorkerViews(workerId);
        Modular.to.pushNamed(
          '/worker/public-profile',
          arguments: WorkerData(
            id: workerId,
            name: name,
            profession: profession,
            categories: categories,
            latitude: latitude,
            longitude: longitude,
            photoUrl: photoUrl,
            rating: rating,
            phone: phone,
            price: price,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with favorite button overlay
            Stack(
              children: [
                // Profile Image
                Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    image: photoUrl != null && photoUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(photoUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: photoUrl == null || photoUrl.isEmpty
                      ? Icon(Icons.person, size: 60, color: Colors.grey[400])
                      : null,
                ),
                // Favorite button overlay
                Positioned(
                  top: 8,
                  right: 8,
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUserId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final userData =
                          snapshot.data?.data() as Map<String, dynamic>?;
                      final favorites =
                          (userData?['favoriteWorkers'] as List<dynamic>?)
                              ?.map((e) => e.toString())
                              .toList() ??
                          [];
                      final isFavorite = favorites.contains(workerId);

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: IconButton(
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          onPressed: () =>
                              _toggleFavorite(workerId, isFavorite),
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? Colors.red : Colors.grey,
                            size: 20,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            // Card content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF212121),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Profession
                    if (profession != 'Sin profesión especificada')
                      Text(
                        profession,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF616161),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                    const SizedBox(height: 6),

                    // Location & Distance
                    Row(
                      children: [
                        if (distance.isNotEmpty) ...[
                          const Icon(
                            Icons.location_on,
                            size: 12,
                            color: Color(0xFF616161),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            distance,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF616161),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                workerLocation?['isFixed'] == true
                                    ? Icons.store
                                    : Icons.directions_car,
                                size: 12,
                                color: workerLocation?['isFixed'] == true
                                    ? Styles.primaryColor
                                    : const Color(0xFF616161),
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  workerLocation?['isFixed'] == true &&
                                          workerLocation?['locationName'] !=
                                              null
                                      ? workerLocation!['locationName']
                                      : 'A domicilio',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: workerLocation?['isFixed'] == true
                                        ? Styles.primaryColor
                                        : const Color(0xFF616161),
                                    fontWeight:
                                        workerLocation?['isFixed'] == true
                                        ? FontWeight.w500
                                        : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),
                    // Rating
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF212121),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '($reviews)',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Price
                    Text(
                      price.isNotEmpty ? 'Bs $price' : 'Consultar',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF001BB7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
