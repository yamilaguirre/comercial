import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_modular/flutter_modular.dart'
    hide ModularWatchExtension;

import '../../theme/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/location_service.dart';
import '../../services/chat_service.dart';
import 'worker_location_search_screen.dart'; // For WorkerData

class WorkerSavedScreen extends StatefulWidget {
  const WorkerSavedScreen({super.key});

  @override
  State<WorkerSavedScreen> createState() => _WorkerSavedScreenState();
}

class _WorkerSavedScreenState extends State<WorkerSavedScreen> {
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

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final currentUserId = authService.currentUser?.uid;

    if (currentUserId == null) {
      return Scaffold(body: Center(child: Text('Debes iniciar sesión')));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Guardados',
          style: TextStyles.title.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Styles.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black87),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(height: Styles.spacingMedium),

          // Lista de trabajadores guardados desde Firebase
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUserId)
                  .snapshots(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!userSnapshot.hasData) {
                  return const Center(
                    child: Text('No hay trabajadores guardados'),
                  );
                }

                final userData =
                    userSnapshot.data?.data() as Map<String, dynamic>?;
                final favoriteWorkers =
                    (userData?['favoriteWorkers'] as List<dynamic>?) ?? [];

                if (favoriteWorkers.isEmpty) {
                  return const Center(
                    child: Text('No hay trabajadores guardados'),
                  );
                }

                return FutureBuilder<List<DocumentSnapshot>>(
                  future: Future.wait(
                    favoriteWorkers.map((workerId) {
                      return FirebaseFirestore.instance
                          .collection('users')
                          .doc(workerId)
                          .get();
                    }),
                  ),
                  builder: (context, workersSnapshot) {
                    if (workersSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!workersSnapshot.hasData ||
                        workersSnapshot.data!.isEmpty) {
                      return const Center(
                        child: Text('No hay trabajadores guardados'),
                      );
                    }

                    final workers = workersSnapshot.data!
                        .where((doc) => doc.exists)
                        .toList();

                    if (workers.isEmpty) {
                      return const Center(
                        child: Text('No hay trabajadores guardados'),
                      );
                    }

                    // Obtenemos la ubicación del usuario para calcular distancia
                    return StreamBuilder<Position>(
                      stream: Geolocator.getPositionStream(
                        locationSettings: const LocationSettings(
                          accuracy: LocationAccuracy.high,
                          distanceFilter: 10,
                        ),
                      ),
                      builder: (context, positionSnapshot) {
                        final userLocation = positionSnapshot.data;

                        return ListView.builder(
                          padding: EdgeInsets.symmetric(
                            horizontal: Styles.spacingMedium,
                          ),
                          itemCount: workers.length,
                          itemBuilder: (context, index) {
                            final workerDoc = workers[index];
                            final data =
                                workerDoc.data() as Map<String, dynamic>;
                            final name = data['name'] ?? 'Sin nombre';

                            // Calcular distancia real si ambos tienen ubicación
                            String distance = '';
                            final workerLocation =
                                data['location'] as Map<String, dynamic>?;

                            if (workerLocation != null &&
                                userLocation != null) {
                              final workerLat =
                                  (workerLocation['latitude'] as num?)
                                      ?.toDouble();
                              final workerLng =
                                  (workerLocation['longitude'] as num?)
                                      ?.toDouble();

                              if (workerLat != null && workerLng != null) {
                                final distanceInMeters =
                                    Geolocator.distanceBetween(
                                      userLocation.latitude,
                                      userLocation.longitude,
                                      workerLat,
                                      workerLng,
                                    );
                                final distanceKm = distanceInMeters / 1000;

                                if (distanceKm < 1) {
                                  distance = '${distanceInMeters.toInt()}m';
                                } else {
                                  distance =
                                      '${distanceKm.toStringAsFixed(1)} km';
                                }
                              }
                            }

                            // Extraer profesión (lógica compleja copiada de home_work_screen)
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
                                  profession = allSubcategories
                                      .take(2)
                                      .join(' • ');
                                } else {
                                  final firstProfession =
                                      professionsData[0]
                                          as Map<String, dynamic>?;
                                  final category =
                                      firstProfession?['category'] as String? ??
                                      '';
                                  if (category.isNotEmpty) {
                                    profession = category;
                                  }
                                }
                              }
                            }

                            // Stream para el rating
                            return StreamBuilder<Map<String, dynamic>>(
                              stream:
                                  LocationService.calculateWorkerRatingStream(
                                    workerDoc.id,
                                  ),
                              builder: (context, ratingSnapshot) {
                                final ratingData =
                                    ratingSnapshot.data ??
                                    {'rating': 0.0, 'reviews': 0};

                                final rating = (ratingData['rating'] as num)
                                    .toDouble();
                                final reviews = ratingData['reviews'] as int;

                                return _buildWorkerCard(
                                  workerId: workerDoc.id,
                                  name: name,
                                  profession: profession,
                                  rating: rating,
                                  reviews: reviews,
                                  price: (data['price']?.toString() ?? '')
                                      .trim(),
                                  distance: distance,
                                  services:
                                      (data['services'] as List<dynamic>?)
                                          ?.map((s) => s.toString())
                                          .toList() ??
                                      [],
                                  photoUrl: data['photoUrl'] as String?,
                                  phone: data['phoneNumber'] as String? ?? '',
                                  latitude:
                                      workerLocation?['latitude'] as double? ??
                                      0.0,
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
                                );
                              },
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
      ),
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
    required double latitude,
    required double longitude,
    required List<String> categories,
  }) {
    final authService = context.read<AuthService>();
    final currentUserId = authService.currentUser?.uid ?? '';

    return Container(
      margin: EdgeInsets.only(bottom: Styles.spacingMedium),
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
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Foto de perfil con botón "Ver Perfil"
                Column(
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                          ? NetworkImage(photoUrl)
                          : null,
                      child: photoUrl == null || photoUrl.isEmpty
                          ? Icon(
                              Icons.person,
                              size: 40,
                              color: Colors.grey[400],
                            )
                          : null,
                    ),
                    const SizedBox(height: 8),
                    InkWell(
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF001BB7).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Ver Perfil',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF001BB7),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // Información del trabajador (Nombre + Rating)
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
                      const SizedBox(height: 6),

                      // Estrellas de rating (clickeables)
                      GestureDetector(
                        onTapDown: (details) {
                          _showRatingDialog(
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

            const SizedBox(height: 18),

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
                      price.isNotEmpty ? 'Bs $price' : price,
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
                      rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF212121),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Profesión como Chip
            if (profession != 'Sin profesión especificada')
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  profession,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF616161),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            const SizedBox(height: 18),

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

            const SizedBox(height: 20),

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

      if (chatId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al crear conversación')),
          );
        }
        return;
      }

      // Navegar a chat
      if (mounted) {
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

    // Limpiar el número (quitar espacios, guiones, etc.)
    String cleanPhone = phone.replaceAll(RegExp(r'[^\\d+]'), '');

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

    // Verificar si ya existe una calificación de este usuario
    final existingFeedback = await FirebaseFirestore.instance
        .collection('feedback')
        .where('workerId', isEqualTo: workerId)
        .where('userId', isEqualTo: currentUserId)
        .limit(1)
        .get();

    int selectedRating = 0;
    bool isEditing = false;

    if (existingFeedback.docs.isNotEmpty) {
      final existingRatingValue =
          (existingFeedback.docs.first.data()['rating'] as num?)?.toInt() ?? 0;
      selectedRating = existingRatingValue;
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
