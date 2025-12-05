import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';

import 'package:flutter_modular/flutter_modular.dart'
    hide ModularWatchExtension;

import '../../theme/theme.dart';
import '../../providers/auth_provider.dart';

import '../../services/location_service.dart';
import '../../services/profile_views_service.dart';
import 'worker_location_search_screen.dart';

import 'components/add_to_worker_collection_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

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
    // Obtener el usuario actual que está viendo el perfil
    final authService = Provider.of<AuthService>(context, listen: false);
    final viewerId = authService.currentUser?.uid;

    if (viewerId == null || viewerId == workerId) {
      // No registrar si no hay usuario logueado o si el trabajador se ve a sí mismo
      return;
    }

    try {
      await ProfileViewsService.registerProfileView(
        workerId: workerId,
        viewerId: viewerId,
      );
    } catch (e) {
      debugPrint('Error registrando vista de perfil: $e');
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

          // NUEVO: Verificar que el trabajador esté VERIFICADO
          final verificationStatus = data['verificationStatus'] as String?;
          if (verificationStatus != 'verified') {
            return false;
          }

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

        // Ordenar por última actualización del perfil (más recientes primero)
        // Esto prioriza a trabajadores que actualizaron su precio recientemente
        filteredWorkers.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;

          final aProfile = aData['profile'] as Map<String, dynamic>?;
          final bProfile = bData['profile'] as Map<String, dynamic>?;

          final aUpdatedAt = aProfile?['updatedAt'] as Timestamp?;
          final bUpdatedAt = bProfile?['updatedAt'] as Timestamp?;

          // Si ambos tienen updatedAt, ordenar por eso
          if (aUpdatedAt != null && bUpdatedAt != null) {
            return bUpdatedAt.compareTo(aUpdatedAt);
          }

          // Si ninguno tiene, ordenar por ID del documento
          if (aUpdatedAt == null && bUpdatedAt == null) {
            return b.id.compareTo(a.id);
          }

          // Dar prioridad a los que tienen updatedAt
          if (aUpdatedAt == null) return 1;
          return -1;
        });

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

        // Check premium status for workers and separate into lists
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('premium_users')
              .where('status', isEqualTo: 'active')
              .snapshots(),
          builder: (context, premiumSnapshot) {
            final premiumUserIdsMap = <String, Timestamp>{};

            if (premiumSnapshot.hasData) {
              for (var doc in premiumSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final startedAt = data['startedAt'] as Timestamp?;
                if (startedAt != null) {
                  premiumUserIdsMap[doc.id] = startedAt;
                }
              }
            }

            // Separate workers into premium and free
            final premiumWorkers = <QueryDocumentSnapshot>[];
            final freeWorkers = <QueryDocumentSnapshot>[];

            for (var worker in filteredWorkers) {
              if (premiumUserIdsMap.containsKey(worker.id)) {
                premiumWorkers.add(worker);
              } else {
                freeWorkers.add(worker);
              }
            }

            // Sort premium workers by subscription date (most recent first)
            premiumWorkers.sort((a, b) {
              final aStartedAt = premiumUserIdsMap[a.id];
              final bStartedAt = premiumUserIdsMap[b.id];
              if (aStartedAt == null || bStartedAt == null) return 0;
              return bStartedAt.compareTo(aStartedAt); // Descending order
            });

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

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Premium workers horizontal section
                    if (premiumWorkers.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 12),
                        child: Text(
                          'Trabajadores Premium',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Styles.textPrimary,
                          ),
                        ),
                      ),
                      _buildPremiumWorkersSection(
                        premiumWorkers,
                        userLocation,
                        currentUserId,
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 12),
                        child: Text(
                          'Otros trabajadores',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Styles.textPrimary,
                          ),
                        ),
                      ),
                    ],

                    // Free workers grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            childAspectRatio: 0.62,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemCount: freeWorkers.length,
                      itemBuilder: (context, index) {
                        final workerDoc = freeWorkers[index];
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
                          final workerLng =
                              (workerLocation['longitude'] as num?)?.toDouble();

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

                        // Extraer profesión
                        final profileMap =
                            data['profile'] as Map<String, dynamic>?;
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
                        if (professionsData != null &&
                            professionsData.isNotEmpty) {
                          final List<String> allSubcategories = [];

                          for (var prof in professionsData) {
                            final profMap = prof as Map<String, dynamic>?;
                            final subcategories =
                                profMap?['subcategories'] as List<dynamic>?;

                            if (subcategories != null &&
                                subcategories.isNotEmpty) {
                              allSubcategories.addAll(
                                subcategories.map((s) => s.toString()),
                              );
                            }
                          }

                          if (profession == 'Sin profesión especificada') {
                            if (allSubcategories.isNotEmpty) {
                              profession = allSubcategories.take(2).join(' • ');
                            } else {
                              final firstProfession =
                                  professionsData[0] as Map<String, dynamic>?;
                              final category =
                                  firstProfession?['category'] as String? ?? '';
                              if (category.isNotEmpty) {
                                profession = category;
                              }
                            }
                          }
                        }

                        return StreamBuilder<Map<String, dynamic>>(
                          stream: LocationService.calculateWorkerRatingStream(
                            workerDoc.id,
                          ),
                          builder: (context, ratingSnapshot) {
                            final ratingData =
                                ratingSnapshot.data ??
                                {'rating': 0.0, 'reviews': 0};

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
                              latitude:
                                  workerLocation?['latitude'] as double? ?? 0.0,
                              longitude:
                                  workerLocation?['longitude'] as double? ??
                                  0.0,
                              categories:
                                  professionsData
                                      ?.map(
                                        (p) =>
                                            (p
                                                    as Map<
                                                      String,
                                                      dynamic
                                                    >?)?['category']
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
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPremiumWorkersSection(
    List<QueryDocumentSnapshot> premiumWorkers,
    Position? userLocation,
    String? currentUserId,
  ) {
    return SizedBox(
      height: 210, // Increased height slightly for better spacing
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: premiumWorkers.length,
        itemBuilder: (context, index) {
          final workerDoc = premiumWorkers[index];
          final data = workerDoc.data() as Map<String, dynamic>;

          final name = data['name'] as String? ?? '';
          if (name.isEmpty) return const SizedBox.shrink();

          // Calculate distance
          String distance = '';
          final workerLocation = data['location'] as Map<String, dynamic>?;
          final locationSettings =
              data['locationSettings'] as Map<String, dynamic>?;
          final showOnMap = locationSettings?['showOnMap'] as bool? ?? true;

          if (workerLocation != null && userLocation != null && showOnMap) {
            final workerLat = (workerLocation['latitude'] as num?)?.toDouble();
            final workerLng = (workerLocation['longitude'] as num?)?.toDouble();

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

          // Extract profession
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
            final List<String> allSubcategories = [];

            for (var prof in professionsData) {
              final profMap = prof as Map<String, dynamic>?;
              final subcategories = profMap?['subcategories'] as List<dynamic>?;

              if (subcategories != null && subcategories.isNotEmpty) {
                allSubcategories.addAll(subcategories.map((s) => s.toString()));
              }
            }

            if (profession == 'Sin profesión especificada') {
              if (allSubcategories.isNotEmpty) {
                profession = allSubcategories.take(2).join(' • ');
              } else {
                final firstProfession =
                    professionsData[0] as Map<String, dynamic>?;
                final category = firstProfession?['category'] as String? ?? '';
                if (category.isNotEmpty) {
                  profession = category;
                }
              }
            }
          }

          return StreamBuilder<Map<String, dynamic>>(
            stream: LocationService.calculateWorkerRatingStream(workerDoc.id),
            builder: (context, ratingSnapshot) {
              final ratingData =
                  ratingSnapshot.data ?? {'rating': 0.0, 'reviews': 0};

              return _buildPremiumWorkerCard(
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
      ),
    );
  }

  Widget _buildPremiumWorkerCard({
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
    final authService = Provider.of<AuthService>(context, listen: false);

    return Container(
      width: 320,
      margin: const EdgeInsets.only(right: 16, bottom: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFF6F00), // Vibrant Orange
            Color(0xFFFFC107), // Vibrant Yellow
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // Left side: Profile image and Ver Perfil button
            Expanded(
              flex: 2,
              child: GestureDetector(
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Profile Image with Favorite Button
                    Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[200],
                            image: photoUrl != null && photoUrl.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(photoUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: photoUrl == null || photoUrl.isEmpty
                              ? Icon(
                                  Icons.person,
                                  size: 40,
                                  color: Colors.grey[400],
                                )
                              : null,
                        ),
                        // Favorite Button Overlay
                        Positioned(
                          right: 0,
                          top: 0,
                          child: StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(authService.currentUser?.uid)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const SizedBox.shrink();
                              }

                              final userData =
                                  snapshot.data!.data()
                                      as Map<String, dynamic>?;
                              final favorites =
                                  (userData?['favoriteWorkers']
                                      as List<dynamic>?) ??
                                  [];
                              final isFavorite = favorites.contains(workerId);

                              return GestureDetector(
                                onTap: () =>
                                    _toggleFavorite(workerId, isFavorite),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
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
                                  child: Icon(
                                    isFavorite
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    size: 16,
                                    color: isFavorite
                                        ? Colors.red
                                        : Colors.grey,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Ver Perfil button
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Styles.primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Ver Perfil',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Right side: Worker info
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Name and rating
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF212121),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              size: 14,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${rating.toStringAsFixed(1)} ($reviews)',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF616161),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Profession
                    if (profession != 'Sin profesión especificada')
                      Text(
                        profession,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF616161),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    // Price
                    if (price.isNotEmpty)
                      Row(
                        children: [
                          const Text(
                            'Desde ',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF616161),
                            ),
                          ),
                          Text(
                            price,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Styles.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 4),
                    // Distance
                    if (distance.isNotEmpty)
                      Row(
                        children: [
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
                        ],
                      ),
                    const SizedBox(height: 12),
                    // Action buttons
                    Row(
                      children: [
                        // Llamar button
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _makePhoneCall(phone),
                            icon: const Icon(Icons.phone, size: 16),
                            label: const Text('Llamar'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Styles.primaryColor,
                              side: const BorderSide(
                                color: Styles.primaryColor,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              textStyle: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Mensaje button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showContactOptions(
                              context: context,
                              workerId: workerId,
                              workerName: name,
                              workerPhoto: photoUrl,
                              workerPhone: phone,
                            ),
                            icon: const Icon(Icons.message, size: 16),
                            label: const Text('Mensaje'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              textStyle: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                      ],
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

  // Helper methods for premium worker actions
  Future<void> _makePhoneCall(String phone) async {
    if (phone.isNotEmpty) {
      final Uri launchUri = Uri(scheme: 'tel', path: phone);
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo realizar la llamada')),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Número de teléfono no disponible')),
        );
      }
    }
  }

  void _showContactOptions({
    required BuildContext context,
    required String workerId,
    required String workerName,
    String? workerPhoto,
    required String workerPhone,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Contactar a $workerName',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            // WhatsApp option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.phone, color: Colors.white),
              ),
              title: const Text('Contactar por WhatsApp'),
              subtitle: const Text('Enviar mensaje directo'),
              onTap: () async {
                Navigator.pop(context);
                final whatsappUrl = Uri.parse('https://wa.me/$workerPhone');
                if (await canLaunchUrl(whatsappUrl)) {
                  await launchUrl(
                    whatsappUrl,
                    mode: LaunchMode.externalApplication,
                  );
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No se pudo abrir WhatsApp'),
                      ),
                    );
                  }
                }
              },
            ),
            const Divider(),
            // In-app chat option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Styles.primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.chat_bubble, color: Colors.white),
              ),
              title: const Text('Chat en la app'),
              subtitle: const Text('Mensajería interna'),
              onTap: () {
                Navigator.pop(context);
                Modular.to.pushNamed(
                  '/worker/chat-detail',
                  arguments: {
                    'chatId': workerId,
                    'otherUserId': workerId,
                    'otherUserName': workerName,
                    'otherUserPhoto': workerPhoto,
                    'otherUserPhone': workerPhone,
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
