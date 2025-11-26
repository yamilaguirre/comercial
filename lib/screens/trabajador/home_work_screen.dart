import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../services/location_service.dart';
import 'worker_location_search_screen.dart';
import 'chat/chat_detail_screen.dart';

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

  Future<void> _initializeWorkerLocation() async {
    final authService = context.read<AuthService>();
    final currentUser = authService.currentUser;

    if (currentUser != null && !_locationInitialized) {
      _locationInitialized = true;

      // Inicializar perfil del trabajador (ubicación y rating)
      await LocationService.initializeWorkerProfile(currentUser.uid);

      // Iniciar tracking de ubicación continuo
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

  @override
  void dispose() {
    _searchController.dispose();
    // Detener tracking cuando se cierre la pantalla
    LocationService().stopLocationTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header con logo y búsqueda
            _buildHeader(),

            // Contenido scrolleable
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),

                      // Botón de búsqueda por ubicación
                      _buildLocationButton(),

                      const SizedBox(height: 24),

                      // Título de la sección
                      const Text(
                        'Destacados cerca de ti',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF212121),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Lista de trabajadores
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
          .where('role', isEqualTo: 'trabajo')
          .where('status', isEqualTo: 'trabajo')
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

        // Filtrar por búsqueda Y excluir al usuario actual
        final filteredWorkers = workers.where((doc) {
          // Excluir al usuario actual
          if (doc.id == currentUserId) return false;

          if (_searchQuery.isEmpty) return true;

          final data = doc.data() as Map<String, dynamic>;
          final name = (data['name'] ?? '').toString().toLowerCase();
          final profession = (data['profession'] ?? '')
              .toString()
              .toLowerCase();
          final services =
              (data['services'] as List<dynamic>?)
                  ?.map((s) => s.toString().toLowerCase())
                  .toList() ??
              [];

          return name.contains(_searchQuery) ||
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

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredWorkers.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
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

                // Extraer profesión del array de professions
                String profession = 'Sin profesión especificada';
                final professionsData = data['professions'] as List<dynamic>?;
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

                  // Si tiene subcategorías, mostrar las primeras 2
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
                }

                return _buildWorkerCard(
                  workerId: workerDoc.id,
                  name: name,
                  profession: profession,
                  rating: (data['rating'] ?? 0.0).toDouble(),
                  reviews: data['reviews'] as int? ?? 0,
                  price: data['price'] as String? ?? '',
                  distance: distance,
                  services:
                      (data['services'] as List<dynamic>?)
                          ?.map((s) => s.toString())
                          .toList() ??
                      [],
                  photoUrl: data['photoUrl'] as String?,
                  phone: data['phoneNumber'] as String? ?? '',
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildWorkerCard({
    required String workerId,
    required String name,
    required String profession,
    required double rating,
    required int reviews,
    required String price,
    required String distance,
    required List<String> services,
    String? photoUrl,
    required String phone,
  }) {
    final authService = context.read<AuthService>();
    final currentUserId = authService.currentUser?.uid ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Foto de perfil
                CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                      ? NetworkImage(photoUrl)
                      : null,
                  child: photoUrl == null || photoUrl.isEmpty
                      ? Icon(Icons.person, size: 40, color: Colors.grey[400])
                      : null,
                ),
                const SizedBox(width: 12),

                // Información del trabajador
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF212121),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profession,
                        style: TextStyle(
                          fontSize: 14,
                          color: profession == 'Sin profesión especificada'
                              ? Colors.grey[400]
                              : const Color(0xFF616161),
                          fontStyle: profession == 'Sin profesión especificada'
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Estrellas de rating (clickeables)
                      GestureDetector(
                        onTapDown: (details) {
                          _showRatingDialog(
                            context,
                            workerId: workerId,
                            workerName: name,
                            currentRating: rating,
                          );
                        },
                        child: Row(
                          children: [
                            ...List.generate(5, (index) {
                              if (index < rating.floor()) {
                                return const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 16,
                                );
                              } else if (index < rating) {
                                return const Icon(
                                  Icons.star_half,
                                  color: Colors.amber,
                                  size: 16,
                                );
                              } else {
                                return Icon(
                                  Icons.star_border,
                                  color: Colors.grey[400],
                                  size: 16,
                                );
                              }
                            }),
                            const SizedBox(width: 4),
                            Text(
                              reviews > 0 ? '($reviews)' : '(Sin calificar)',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF616161),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Botón de favorito
                StreamBuilder<DocumentSnapshot>(
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

                    return IconButton(
                      onPressed: () => _toggleFavorite(workerId, isFavorite),
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Colors.red : Colors.grey,
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Precio y distancia
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Desde',
                      style: TextStyle(fontSize: 12, color: Color(0xFF616161)),
                    ),
                    Text(
                      price,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF001BB7),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 16,
                      color: Color(0xFF616161),
                    ),
                    Text(
                      distance,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF616161),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                    Text(
                      '$rating ($reviews)',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF212121),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Tags de servicios
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: services.take(3).map((service) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    service,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF616161),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 12),

            // Botones de acción
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openWhatsApp(phone),
                    icon: const Icon(Icons.phone, size: 18),
                    label: const Text('Llamar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF212121),
                      side: const BorderSide(color: Color(0xFFE0E0E0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _startChat(
                      context,
                      workerId: workerId,
                      workerName: name,
                      workerPhoto: photoUrl,
                    ),
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('Mensaje'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF212121),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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

      // Buscar o crear chat
      String? chatId = await chatService.findExistingChat('general', userIds);

      if (chatId == null || chatId.isEmpty) {
        chatId = await chatService.createChat(
          propertyId: 'general',
          userIds: userIds,
          initialMessage: '¡Hola! Me interesa tu servicio.',
          senderId: currentUserId,
        );
      }

      if (chatId == null || chatId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al crear conversación')),
          );
        }
        return;
      }

      // Navegar a chat
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(
              chatId: chatId!,
              otherUserId: workerId,
              otherUserName: workerName,
              otherUserPhoto: workerPhoto,
            ),
          ),
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

  Future<void> _toggleFavorite(String workerId, bool isFavorite) async {
    final authService = context.read<AuthService>();
    final currentUserId = authService.currentUser?.uid;

    if (currentUserId == null) return;

    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId);

      if (isFavorite) {
        // Remover de favoritos
        await userRef.update({
          'favoriteWorkers': FieldValue.arrayRemove([workerId]),
        });
      } else {
        // Agregar a favoritos
        await userRef.update({
          'favoriteWorkers': FieldValue.arrayUnion([workerId]),
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar favoritos: $e'),
            backgroundColor: Styles.errorColor,
          ),
        );
      }
    }
  }

  // Mostrar diálogo para calificar al trabajador
  Future<void> _showRatingDialog(
    BuildContext context, {
    required String workerId,
    required String workerName,
    required double currentRating,
  }) async {
    int selectedRating = 0;

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Calificar a $workerName'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '¿Cómo calificarías este trabajador?',
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
                          setState(() {
                            selectedRating = index + 1;
                          });
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
                  if (selectedRating > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '$selectedRating ${selectedRating == 1 ? "estrella" : "estrellas"}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
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
                            newRating: selectedRating.toDouble(),
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('¡Calificación guardada!'),
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
                  child: const Text('Calificar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Abrir WhatsApp con el número del trabajador
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

    // Limpiar el número (quitar espacios, guiones, etc.)
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');

    // Si no tiene código de país, agregar +591 (Bolivia)
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
}
