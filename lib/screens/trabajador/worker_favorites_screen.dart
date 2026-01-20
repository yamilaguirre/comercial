import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_modular/flutter_modular.dart'
    hide ModularWatchExtension;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/ad_service.dart';

import '../../theme/theme.dart';
import '../property/components/saved_counter.dart';
import '../../services/worker_saved_service.dart';
import '../../services/location_service.dart';
import '../../services/chat_service.dart';
import '../../services/profile_views_service.dart';
import '../../providers/auth_provider.dart';
import '../../models/saved_collection_model.dart';
import '../../models/contact_filter.dart';
import 'components/worker_collection_card.dart';
import 'components/create_worker_collection_dialog.dart';
import 'components/edit_worker_collection_dialog.dart';
import 'worker_location_search_screen.dart'; // For WorkerData

class WorkerFavoritesScreen extends StatefulWidget {
  const WorkerFavoritesScreen({super.key});

  @override
  State<WorkerFavoritesScreen> createState() => _WorkerFavoritesScreenState();
}

class _WorkerFavoritesScreenState extends State<WorkerFavoritesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final WorkerSavedService _savedService = WorkerSavedService();
  bool _locationInitialized = false;

  // Contact filter state
  ContactFilter _selectedFilter = ContactFilter.all;
  Map<ContactFilter, int> _counts = {
    ContactFilter.all: 0,
    ContactFilter.contacted: 0,
    ContactFilter.notContacted: 0,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeWorkerLocation();
    _loadCounts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeWorkerLocation() async {
    final authService = context.read<AuthService>();
    final currentUser = authService.currentUser;

    if (currentUser != null && !_locationInitialized) {
      _locationInitialized = true;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
    }
  }

  Future<void> _loadCounts() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid ?? '';

    final counts = await _savedService.getContactStatusCounts(userId);

    if (mounted) {
      setState(() {
        _counts = counts;
      });
    }
  }

  void _onFilterChanged(ContactFilter filter) {
    setState(() {
      _selectedFilter = filter;
    });
  }

  Future<void> _createCollection() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const CreateWorkerCollectionDialog(),
    );

    if (name == null || name.isEmpty) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid ?? '';

    final collectionId = await _savedService.createCollection(userId, name);

    if (collectionId != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Colección "$name" creada')));
      _loadCounts();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al crear la colección')),
      );
    }
  }

  Future<void> _editCollection(SavedCollection collection) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) =>
          EditWorkerCollectionDialog(currentName: collection.name),
    );

    if (newName == null || newName.isEmpty || newName == collection.name) {
      return;
    }

    final success = await _savedService.updateCollectionName(
      collection.id,
      newName,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Colección actualizada'
                : 'Error al actualizar la colección',
          ),
        ),
      );
    }
  }

  Future<void> _deleteCollection(SavedCollection collection) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar colección'),
        content: Text(
          '¿Estás seguro de eliminar "${collection.name}"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await _savedService.deleteCollection(collection.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Colección eliminada' : 'Error al eliminar la colección',
          ),
        ),
      );
      if (success) _loadCounts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final userId = authService.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título y búsqueda
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Guardados',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.search, color: Colors.black),
                        onPressed: () {
                          showSearch(
                            context: context,
                            delegate: FavoritesSearchDelegate(
                              userId: userId,
                              savedService: _savedService,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Tabs - estilo igual a propiedades
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: Styles.primaryColor,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Styles.primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.grey[700],
                      labelStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                      dividerColor: Colors.transparent,
                      splashFactory: NoSplash.splashFactory,
                      overlayColor: MaterialStateProperty.all(
                        Colors.transparent,
                      ),
                      tabs: const [
                        Tab(
                          height: 44,
                          child: Center(
                            child: Text(
                              'Todo Guardado',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Tab(
                          height: 44,
                          child: Center(
                            child: Text(
                              'Mis Colecciones',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Contadores de filtro (solo en la pestaña "Todo Guardado")
                  AnimatedBuilder(
                    animation: _tabController,
                    builder: (context, child) {
                      if (_tabController.index == 0) {
                        return Column(
                          children: [
                            // Use horizontal scroll on wide screens, Wrap on narrow screens
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final useWrap = constraints.maxWidth < 420;
                                // Always use horizontal scroll and keep the default
                                // counter size; users can scroll to see all buttons.
                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      SavedCounter(
                                        icon: Icons.favorite,
                                        label: ContactFilter.all.label,
                                        count: _counts[ContactFilter.all] ?? 0,
                                        color: Styles.primaryColor,
                                        isSelected:
                                            _selectedFilter ==
                                            ContactFilter.all,
                                        onTap: () =>
                                            _onFilterChanged(ContactFilter.all),
                                      ),
                                      const SizedBox(width: 12),
                                      SavedCounter(
                                        icon: Icons.chat_bubble_outline,
                                        label: ContactFilter.notContacted.label,
                                        count:
                                            _counts[ContactFilter
                                                .notContacted] ??
                                            0,
                                        color: Colors.orange,
                                        isSelected:
                                            _selectedFilter ==
                                            ContactFilter.notContacted,
                                        onTap: () => _onFilterChanged(
                                          ContactFilter.notContacted,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      SavedCounter(
                                        icon: Icons.chat,
                                        label: ContactFilter.contacted.label,
                                        count:
                                            _counts[ContactFilter.contacted] ??
                                            0,
                                        color: Colors.green,
                                        isSelected:
                                            _selectedFilter ==
                                            ContactFilter.contacted,
                                        onTap: () => _onFilterChanged(
                                          ContactFilter.contacted,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      }
                      return const SizedBox(height: 16);
                    },
                  ),
                ],
              ),
            ),

            // TABS CONTENT
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAllSavedTab(userId),
                  _buildCollectionsTab(userId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCounter({
    required ContactFilter filter,
    required IconData icon,
    required String label,
    required int count,
  }) {
    final isSelected = _selectedFilter == filter;
    final color = isSelected ? Styles.primaryColor : Colors.grey[600]!;

    return GestureDetector(
      onTap: () => _onFilterChanged(filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Styles.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Styles.primaryColor : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              count.toString(),
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllSavedTab(String userId) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _savedService.getFilteredSavedWorkers(
              userId,
              _selectedFilter,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final workers = snapshot.data ?? [];

              if (workers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.favorite_border,
                        size: 80,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay trabajadores en esta categoría',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return StreamBuilder<Position>(
                stream: Geolocator.getPositionStream(
                  locationSettings: const LocationSettings(
                    accuracy: LocationAccuracy.high,
                    distanceFilter: 10,
                  ),
                ),
                builder: (context, positionSnapshot) {
                  final userLocation = positionSnapshot.data;

                  return GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 200,
                          childAspectRatio: 0.62,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: workers.length,
                    itemBuilder: (context, index) {
                      final data = workers[index];
                      final workerId = data['id'] as String;
                      final name = data['name'] ?? 'Sin nombre';

                      // Calcular distancia real si ambos tienen ubicación
                      String distance = '';
                      final workerLocation =
                          data['location'] as Map<String, dynamic>?;

                      if (workerLocation != null && userLocation != null) {
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

                      // Stream para el rating
                      return StreamBuilder<Map<String, dynamic>>(
                        stream: LocationService.calculateWorkerRatingStream(
                          workerId,
                        ),
                        builder: (context, ratingSnapshot) {
                          final ratingData =
                              ratingSnapshot.data ??
                              {'rating': 0.0, 'reviews': 0};
                          final rating = (ratingData['rating'] as num)
                              .toDouble();
                          final reviews = ratingData['reviews'] as int;

                          return _buildCompactWorkerCard(
                            workerId: workerId,
                            name: name,
                            profession: profession,
                            rating: rating,
                            reviews: reviews,
                            price: (data['price']?.toString() ?? '').trim(),
                            distance: distance,
                            photoUrl: data['photoUrl'] as String?,
                            phone: data['phoneNumber'] as String? ?? '',
                            latitude:
                                workerLocation?['latitude'] as double? ?? 0.0,
                            longitude:
                                workerLocation?['longitude'] as double? ?? 0.0,
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
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCollectionsTab(String userId) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _createCollection,
              icon: const Icon(Icons.add),
              label: const Text('Crear nueva colección'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Styles.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<SavedCollection>>(
            stream: _savedService.getUserCollections(userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Center(child: Text('Error al cargar colecciones'));
              }
              final collections = snapshot.data ?? [];
              if (collections.isEmpty) {
                return const Center(child: Text('No tienes colecciones'));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: collections.length,
                itemBuilder: (context, index) {
                  final collection = collections[index];
                  return WorkerCollectionCard(
                    collection: collection,
                    onTap: () {
                      Modular.to.pushNamed(
                        '/worker/collection-detail',
                        arguments: collection,
                      );
                    },
                    onEdit: () => _editCollection(collection),
                    onDelete: () => _deleteCollection(collection),
                  );
                },
              );
            },
          ),
        ),
      ],
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

  Future<void> _incrementWorkerViews(String workerId) async {
    try {
      print('🔍 [VIEWS-FAVORITES] Intentando registrar vista para: $workerId');

      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;

      if (currentUser == null) {
        print('⚠️ [VIEWS-FAVORITES] No hay usuario logueado');
        return;
      }

      if (currentUser.uid == workerId) {
        print('⚠️ [VIEWS-FAVORITES] No se puede ver tu propio perfil');
        return;
      }

      print(
        '📝 [VIEWS-FAVORITES] Llamando a ProfileViewsService.registerProfileView',
      );
      await ProfileViewsService.registerProfileView(
        viewerId: currentUser.uid,
        workerId: workerId,
      );
      print('✅ [VIEWS-FAVORITES] Vista registrada exitosamente');
    } catch (e, stackTrace) {
      print('❌ [VIEWS-FAVORITES] Error registrando vista: $e');
      print('Stack trace: $stackTrace');
    }
  }

  Future<void> _startChat(
    BuildContext context, {
    required String workerId,
    required String workerName,
    String? workerPhoto,
  }) async {
    final authService = context.read<AuthService>();
    final currentUserId = authService.currentUser?.uid;

    if (currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Debes iniciar sesión')));
      }
      return;
    }

    try {
      final chatService = ChatService();
      final userIds = [currentUserId, workerId];
      String? chatId = await chatService.findExistingChat('general', userIds);
      if (chatId == null || chatId.isEmpty) {
        chatId = await chatService.createChat(
          propertyId: 'general',
          userIds: userIds,
          initialMessage: '¡Hola! Me interesa tu servicio.',
          senderId: currentUserId,
        );
      }
      if (chatId != null && mounted) {
        Modular.to.pushNamed(
          '/worker/chat-detail',
          arguments: {
            'chatId': chatId,
            'otherUserId': workerId,
            'otherUserName': workerName,
            'otherUserPhoto': workerPhoto,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este trabajador no tiene teléfono registrado'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    String cleanPhone = phone.replaceAll(RegExp(r'[^\\d+]'), '');
    if (!cleanPhone.startsWith('+')) {
      cleanPhone = '+591$cleanPhone';
    }
    final whatsappUrl = 'https://wa.me/$cleanPhone';
    try {
      final uri = Uri.parse(whatsappUrl);
      await AdService.instance.showInterstitialThen(() async {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No se pudo abrir WhatsApp'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir WhatsApp: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
          // Recargar la lista
          setState(() {});
        }
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'favoriteWorkers': FieldValue.arrayUnion([workerId]),
            });
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
    }
  }

  Future<void> _showRatingDialog({
    required String workerId,
    required String workerName,
    required double currentRating,
  }) async {
    final authService = context.read<AuthService>();
    final currentUserId = authService.currentUser?.uid;
    if (currentUserId == null) return;

    final existingFeedback = await FirebaseFirestore.instance
        .collection('feedback')
        .where('workerId', isEqualTo: workerId)
        .where('userId', isEqualTo: currentUserId)
        .limit(1)
        .get();

    int selectedRating = 0;
    bool isEditing = false;
    if (existingFeedback.docs.isNotEmpty) {
      selectedRating =
          (existingFeedback.docs.first.data()['rating'] as num?)?.toInt() ?? 0;
      isEditing = true;
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                '${isEditing ? "Editar" : "Calificar a"} $workerName',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isEditing
                        ? 'Edita tu calificación anterior'
                        : '¿Cómo calificarías este trabajador?',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 4,
                    children: List.generate(5, (index) {
                      return IconButton(
                        iconSize: 32,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          setState(() => selectedRating = index + 1);
                        },
                        icon: Icon(
                          index < selectedRating
                              ? Icons.star
                              : Icons.star_border,
                          color: index < selectedRating
                              ? Colors.amber
                              : Colors.grey[400],
                        ),
                      );
                    }),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: selectedRating > 0
                      ? () async {
                          Navigator.pop(dialogContext);
                          await LocationService.updateWorkerRating(
                            workerId: workerId,
                            ratingUserId: currentUserId,
                            newRating: selectedRating.toDouble(),
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isEditing
                                      ? '¡Calificación actualizada!'
                                      : '¡Calificación guardada!',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0033CC),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isEditing ? 'Actualizar' : 'Calificar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// Delegate para búsqueda de trabajadores guardados/favoritos
class FavoritesSearchDelegate extends SearchDelegate<String> {
  final String userId;
  final WorkerSavedService savedService;

  FavoritesSearchDelegate({required this.userId, required this.savedService});

  @override
  String get searchFieldLabel => 'Buscar trabajador...';

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    if (query.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'Busca por nombre o profesión',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: savedService.getFilteredSavedWorkers(userId, ContactFilter.all),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No hay trabajadores guardados'));
        }

        // Filtrar por búsqueda
        final workers = snapshot.data!.where((data) {
          final name = (data['name'] ?? '').toString().toLowerCase();
          final profileMap = data['profile'] as Map<String, dynamic>?;

          String profession =
              (data['profession'] as String? ??
                      profileMap?['profession'] as String? ??
                      '')
                  .toString()
                  .toLowerCase();

          final professionsData =
              (data['professions'] as List<dynamic>?) ??
              (profileMap?['professions'] as List<dynamic>?);

          if (professionsData != null && professionsData.isNotEmpty) {
            for (var prof in professionsData) {
              final profMap = prof as Map<String, dynamic>?;
              final category = (profMap?['category'] as String? ?? '')
                  .toLowerCase();
              final subcategories = profMap?['subcategories'] as List<dynamic>?;

              if (category.contains(query.toLowerCase())) {
                return true;
              }

              if (subcategories != null) {
                for (var sub in subcategories) {
                  if (sub.toString().toLowerCase().contains(
                    query.toLowerCase(),
                  )) {
                    return true;
                  }
                }
              }
            }
          }

          return name.contains(query.toLowerCase()) ||
              profession.contains(query.toLowerCase());
        }).toList();

        if (workers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'No se encontraron resultados para "$query"',
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        }

        return StreamBuilder<Position>(
          stream: Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
            ),
          ),
          builder: (context, positionSnapshot) {
            final userLocation = positionSnapshot.data;

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                childAspectRatio: 0.62,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: workers.length,
              itemBuilder: (context, index) {
                final data = workers[index];
                final workerId = data['id'] as String;
                final name = data['name'] ?? 'Sin nombre';

                // Calcular distancia
                String distance = '';
                final workerLocation =
                    data['location'] as Map<String, dynamic>?;

                if (workerLocation != null && userLocation != null) {
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

                // Extraer profesión
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
                    final subcategories =
                        profMap?['subcategories'] as List<dynamic>?;

                    if (subcategories != null && subcategories.isNotEmpty) {
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
                  stream: LocationService.calculateWorkerRatingStream(workerId),
                  builder: (context, ratingSnapshot) {
                    final ratingData =
                        ratingSnapshot.data ?? {'rating': 0.0, 'reviews': 0};
                    final rating = (ratingData['rating'] as num).toDouble();
                    final reviews = ratingData['reviews'] as int;

                    return _SearchFavoriteCard(
                      workerId: workerId,
                      name: name,
                      profession: profession,
                      rating: rating,
                      reviews: reviews,
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
}

// Widget para tarjeta compacta en búsqueda
class _SearchFavoriteCard extends StatelessWidget {
  final String workerId;
  final String name;
  final String profession;
  final double rating;
  final int reviews;
  final String price;
  final String distance;
  final String? photoUrl;
  final String phone;
  final double latitude;
  final double longitude;
  final List<String> categories;

  const _SearchFavoriteCard({
    required this.workerId,
    required this.name,
    required this.profession,
    required this.rating,
    required this.reviews,
    required this.price,
    required this.distance,
    this.photoUrl,
    required this.phone,
    required this.latitude,
    required this.longitude,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
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
            // Imagen de perfil
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                image: photoUrl != null && photoUrl!.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(photoUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: photoUrl == null || photoUrl!.isEmpty
                  ? Icon(Icons.person, size: 50, color: Colors.grey[400])
                  : null,
            ),
            // Contenido
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (profession != 'Sin profesión especificada')
                      Text(
                        profession,
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 12, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 11),
                        ),
                        if (distance.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              distance,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (price.isNotEmpty)
                      Text(
                        'Bs $price',
                        style: const TextStyle(
                          fontSize: 13,
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
