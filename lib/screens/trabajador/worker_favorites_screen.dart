import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_modular/flutter_modular.dart'
    hide ModularWatchExtension;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/theme.dart';
import '../../services/worker_saved_service.dart';
import '../../services/location_service.dart';
import '../../services/chat_service.dart';
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Guardados',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {
              // TODO: Implementar búsqueda
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Column(
            children: [
              // Tabs
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  labelColor: Colors.black,
                  unselectedLabelColor: Colors.grey[600],
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: const [
                    Tab(text: 'Todo Guardado'),
                    Tab(text: 'Mis Colecciones'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildAllSavedTab(userId), _buildCollectionsTab(userId)],
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
        // Contadores
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCounter(
                  filter: ContactFilter.all,
                  icon: Icons.grid_view,
                  label: 'Todos',
                  count: _counts[ContactFilter.all] ?? 0,
                ),
                const SizedBox(width: 12),
                _buildCounter(
                  filter: ContactFilter.contacted,
                  icon: Icons.chat_bubble_outline,
                  label: 'Contactados',
                  count: _counts[ContactFilter.contacted] ?? 0,
                ),
                const SizedBox(width: 12),
                _buildCounter(
                  filter: ContactFilter.notContacted,
                  icon: Icons.favorite_border,
                  label: 'No contactados',
                  count: _counts[ContactFilter.notContacted] ?? 0,
                ),
              ],
            ),
          ),
        ),
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
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: OutlinedButton.icon(
            onPressed: _createCollection,
            icon: const Icon(Icons.add),
            label: const Text('Crear nueva colección'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Styles.primaryColor,
              side: BorderSide(color: Styles.primaryColor),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
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
      await FirebaseFirestore.instance.collection('users').doc(workerId).set({
        'views': FieldValue.increment(1),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error incrementing views: $e');
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
