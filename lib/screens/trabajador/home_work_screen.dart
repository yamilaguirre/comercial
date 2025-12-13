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
import '../../services/chat_service.dart';
import 'package:chaski_comercial/services/ad_service.dart';

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

    print('🔍 [VIEWS] Intentando registrar vista - Viewer: $viewerId, Worker: $workerId');

    if (viewerId == null) {
      print('⚠️ [VIEWS] No hay usuario logueado, no se registra vista');
      return;
    }

    if (viewerId == workerId) {
      print('⚠️ [VIEWS] Usuario viendo su propio perfil, no se registra vista');
      return;
    }

    try {
      print('📝 [VIEWS] Registrando vista en ProfileViewsService...');
      await ProfileViewsService.registerProfileView(
        workerId: workerId,
        viewerId: viewerId,
      );
      print('✅ [VIEWS] Vista registrada exitosamente');
    } catch (e) {
      print('❌ [VIEWS] Error registrando vista de perfil: $e');
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

  // --- FUNCIÓN: CAMBIAR DE MÓDULO (REDIRECCIÓN A INMOBILIARIA) ---
  void _changeModule() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    if (user == null) {
      Modular.to.navigate('/login');
      return;
    }

    try {
      // Cambiar el rol del usuario a 'inmobiliaria' antes de navegar
      await authService.updateUserRole('inmobiliaria');
      // Navegar al módulo de property (pantalla principal)
      Modular.to.navigate('/property/home');
    } catch (e) {
      debugPrint('Error al cambiar de módulo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 80,
                    ),
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
            // Botón flotante para cambiar de módulo
            Positioned(
              bottom: 24,
              right: 16,
              child: _buildModuleSwitchButton(),
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

  // Botón flotante elegante para cambiar de módulo
  Widget _buildModuleSwitchButton() {
    return GestureDetector(
      onTap: () {
        // Mostrar tooltip o diálogo antes de cambiar
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: const [
                Icon(Icons.home_work, color: Styles.primaryColor, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Cambiar a Inmobiliaria',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: const Text(
              '¿Deseas cambiar al módulo de Inmobiliaria para buscar propiedades?',
              style: TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _changeModule();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Styles.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text('Cambiar'),
              ),
            ],
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Styles.primaryColor, Color(0xFF1565C0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Styles.primaryColor.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.home_work, color: Colors.white, size: 20),
            SizedBox(width: 6),
            Text(
              'Inmobiliaria',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
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
          onTap: () async {
            final authService = Provider.of<AuthService>(
              context,
              listen: false,
            );
            if (authService.isPremium) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const WorkerLocationSearchScreen(),
                ),
              );
            } else {
              await AdService.instance.showInterstitialThen(() async {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const WorkerLocationSearchScreen(),
                  ),
                );
              });
            }
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
    final isPremiumUser = authService.isPremium;

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
          // Excluir al usuario actual SOLO si NO es premium
          // Si es premium, permitirle verse para ver cómo se ve su perfil
          if (doc.id == currentUserId && !isPremiumUser) return false;

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

        // Ordenar por última re-publicación (más recientes primero)
        // Esto prioriza a trabajadores que se re-publicaron recientemente
        filteredWorkers.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;

          // Priorizar lastRepublish sobre updatedAt
          final aRepublish = aData['lastRepublish'] as Timestamp?;
          final bRepublish = bData['lastRepublish'] as Timestamp?;

          // Si ambos tienen lastRepublish, ordenar por eso
          if (aRepublish != null && bRepublish != null) {
            return bRepublish.compareTo(aRepublish);
          }

          // Si ninguno tiene lastRepublish, usar updatedAt del profile
          if (aRepublish == null && bRepublish == null) {
            final aProfile = aData['profile'] as Map<String, dynamic>?;
            final bProfile = bData['profile'] as Map<String, dynamic>?;

            final aUpdatedAt = aProfile?['updatedAt'] as Timestamp?;
            final bUpdatedAt = bProfile?['updatedAt'] as Timestamp?;

            if (aUpdatedAt != null && bUpdatedAt != null) {
              return bUpdatedAt.compareTo(aUpdatedAt);
            }

            if (aUpdatedAt == null && bUpdatedAt == null) {
              return b.id.compareTo(a.id);
            }

            if (aUpdatedAt == null) return 1;
            return -1;
          }

          // Dar prioridad a los que tienen lastRepublish
          if (aRepublish == null) return 1;
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
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).padding.bottom + 120,
                      ),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            childAspectRatio: 0.50,
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
                              experienceLevel:
                                  profileMap?['experienceLevel'] as String? ??
                                  '',
                              currency:
                                  (profileMap?['currency'] as String?) ?? 'Bs',
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
      height: 240, // Increased height for experience level badge
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
                experienceLevel:
                    profileMap?['experienceLevel'] as String? ?? '',
                currency: (profileMap?['currency'] as String?) ?? 'Bs',
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
    required String experienceLevel,
    required String currency,
  }) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return Container(
      width: 340, // Increased width to prevent overflow
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
                        const SizedBox(height: 6),
                        // Experience Level Badge
                        if (experienceLevel.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getLevelColor(
                                experienceLevel,
                              ).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _getLevelColor(experienceLevel),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getLevelIcon(experienceLevel),
                                  size: 12,
                                  color: _getLevelColor(experienceLevel),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  experienceLevel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: _getLevelColor(experienceLevel),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
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
                    const SizedBox(height: 2),
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
                            '$currency $price',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Styles.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 2),
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
                    const SizedBox(height: 8),
                    // Action buttons
                    Row(
                      children: [
                        // Llamar button
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _makePhoneCall(phone),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Styles.primaryColor,
                              side: const BorderSide(
                                color: Styles.primaryColor,
                                width: 1,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                                vertical: 8,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.phone, size: 13),
                                SizedBox(width: 3),
                                Text('Llamar', style: TextStyle(fontSize: 10)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Mensaje button
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _showContactOptions(
                              context: context,
                              workerId: workerId,
                              workerName: name,
                              workerPhoto: photoUrl,
                              workerPhone: phone,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                                vertical: 8,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.message, size: 13),
                                SizedBox(width: 3),
                                Text('Mensaje', style: TextStyle(fontSize: 10)),
                              ],
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
    required String experienceLevel,
    required String currency,
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
            currency: currency,
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
                  height: 160,
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
                padding: const EdgeInsets.all(6.0),
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
                    // Experience Level Badge
                    if (experienceLevel.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getLevelColor(
                            experienceLevel,
                          ).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _getLevelColor(experienceLevel),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getLevelIcon(experienceLevel),
                              size: 11,
                              color: _getLevelColor(experienceLevel),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              experienceLevel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _getLevelColor(experienceLevel),
                              ),
                            ),
                          ],
                        ),
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
                      price.isNotEmpty ? '$currency $price' : 'Consultar',
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
      builder: (modalContext) => Container(
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
                Navigator.pop(modalContext);
                final whatsappUrl = Uri.parse('https://wa.me/$workerPhone');
                if (await canLaunchUrl(whatsappUrl)) {
                  await launchUrl(
                    whatsappUrl,
                    mode: LaunchMode.externalApplication,
                  );
                } else {
                  if (context.mounted) {
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
              onTap: () async {
                Navigator.pop(modalContext);

                // Use the PARENT context (passed to _showContactOptions) for Provider
                // This context is still valid after the modal is popped.
                if (!context.mounted) return;

                final authService = Provider.of<AuthService>(
                  context,
                  listen: false,
                );
                final currentUser = authService.currentUser;
                if (currentUser == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Debes iniciar sesión')),
                  );
                  return;
                }

                try {
                  final chatService = ChatService();
                  final userIds = [currentUser.uid, workerId];
                  String? chatId = await chatService.findExistingChat(
                    'general',
                    userIds,
                  );

                  if (chatId == null) {
                    chatId = await chatService.createChat(
                      propertyId: 'general',
                      userIds: userIds,
                      initialMessage:
                          'Hola, vi tu perfil y me interesa tu servicio.',
                      senderId: currentUser.uid,
                    );
                  }

                  if (chatId != null) {
                    Modular.to.pushNamed(
                      '/worker/chat-detail',
                      arguments: {
                        'chatId': chatId,
                        'otherUserId': workerId,
                        'otherUserName': workerName,
                        'otherUserPhoto': workerPhoto,
                        'otherUserPhone': workerPhone,
                      },
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'básico':
        return Colors.blue;
      case 'intermedio':
        return Colors.orange;
      case 'avanzado':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getLevelIcon(String level) {
    switch (level.toLowerCase()) {
      case 'básico':
        return Icons.star_outline;
      case 'intermedio':
        return Icons.star_half;
      case 'avanzado':
        return Icons.star;
      default:
        return Icons.info_outline;
    }
  }
}
