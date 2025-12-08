import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';

import 'package:flutter_modular/flutter_modular.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../services/location_service.dart';
import 'worker_location_search_screen.dart';

class WorkerPublicProfileScreen extends StatefulWidget {
  final WorkerData worker;

  const WorkerPublicProfileScreen({super.key, required this.worker});

  @override
  State<WorkerPublicProfileScreen> createState() =>
      _WorkerPublicProfileScreenState();
}

class _WorkerPublicProfileScreenState extends State<WorkerPublicProfileScreen> {
  @override
  void initState() {
    super.initState();
  }

  Future<void> _shareWorkerProfile() async {
    final worker = widget.worker;
    final String shareText =
        '''
¡Mira este perfil de trabajador en Job Chasky!
Nombre: ${worker.name}
Profesión: ${worker.profession}
Calificación: ${worker.rating.toStringAsFixed(1)} ⭐
Teléfono: ${worker.phone}

Descarga la app para contactarlo.
''';
    await Clipboard.setData(ClipboardData(text: shareText));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Información copiada al portapapeles')),
      );
    }
  }

  Future<void> _handleRating() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para calificar')),
      );
      return;
    }

    if (currentUser.uid == widget.worker.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No puedes calificarte a ti mismo')),
      );
      return;
    }

    _showRatingDialog(currentUser.uid);
  }

  void _showRatingDialog(String userId) {
    showDialog(
      context: context,
      builder: (context) {
        double currentRating = 0;
        bool isLoading = true;
        String? feedbackId;

        return StatefulBuilder(
          builder: (context, setState) {
            if (isLoading) {
              // Cargar calificación existente
              FirebaseFirestore.instance
                  .collection('feedback')
                  .where('userId', isEqualTo: userId)
                  .where('workerId', isEqualTo: widget.worker.id)
                  .limit(1)
                  .get()
                  .then((snapshot) {
                    if (snapshot.docs.isNotEmpty) {
                      final data = snapshot.docs.first.data();
                      if (mounted) {
                        setState(() {
                          currentRating = (data['rating'] as num).toDouble();
                          feedbackId = snapshot.docs.first.id;
                          isLoading = false;
                        });
                      }
                    } else {
                      if (mounted) {
                        setState(() {
                          isLoading = false;
                        });
                      }
                    }
                  });
              return const Center(child: CircularProgressIndicator());
            }

            return AlertDialog(
              title: Text(
                feedbackId != null
                    ? 'Editar tu calificación'
                    : 'Calificar a ${widget.worker.name}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Toca las estrellas para calificar'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < currentRating
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 32,
                        ),
                        onPressed: () {
                          setState(() {
                            currentRating = index + 1.0;
                          });
                        },
                      );
                    }),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: currentRating > 0
                      ? () async {
                          try {
                            final feedbackRef = FirebaseFirestore.instance
                                .collection('feedback');

                            if (feedbackId != null) {
                              // Actualizar existente
                              await feedbackRef.doc(feedbackId).update({
                                'rating': currentRating,
                                'updatedAt': FieldValue.serverTimestamp(),
                              });
                            } else {
                              // Crear nuevo
                              await feedbackRef.add({
                                'userId': userId,
                                'workerId': widget.worker.id,
                                'rating': currentRating,
                                'createdAt': FieldValue.serverTimestamp(),
                                'updatedAt': FieldValue.serverTimestamp(),
                              });
                            }

                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '¡Gracias por tu calificación!',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF001BB7),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.worker.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Modular.to.pop(),
              ),
            ),
            body: const Center(child: Text('Trabajador no encontrado')),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final profile = data['profile'] as Map<String, dynamic>?;

        // Leer datos con validaciones
        final String description =
            profile?['description']?.toString() ?? 'Sin descripción';
        final String availability =
            profile?['availability']?.toString() ?? 'No disponible';
        final String price =
            (profile?['price']?.toString() ?? data['price']?.toString() ?? '')
                .trim();
        final String currency =
            profile?['currency']?.toString() ?? 'Bs';
        final String experienceLevel =
            profile?['experienceLevel']?.toString() ?? '';
        final List<dynamic> portfolioImagesList =
            profile?['portfolioImages'] as List<dynamic>? ?? [];
        final List<dynamic> portfolioVideosList =
            profile?['portfolioVideos'] as List<dynamic>? ?? [];

        // Extraer servicios desde professions
        final List<String> services = [];
        final professions = profile?['professions'] as List<dynamic>?;
        if (professions != null) {
          for (var prof in professions) {
            final subcategories = prof['subcategories'] as List<dynamic>?;
            if (subcategories != null) {
              services.addAll(subcategories.map((e) => e.toString()));
            }
          }
        } else {
          // Fallback antiguo por si acaso
          final oldServices = (data['services'] as List<dynamic>?);
          if (oldServices != null) {
            services.addAll(oldServices.map((s) => s.toString()));
          }
        }

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Modular.to.pop(),
            ),
            title: const Text(
              'Perfil',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined, color: Colors.black),
                onPressed: _shareWorkerProfile,
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header con Foto y Datos Básicos
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 45,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: widget.worker.photoUrl != null
                            ? NetworkImage(widget.worker.photoUrl!)
                            : null,
                        child: widget.worker.photoUrl == null
                            ? const Icon(
                                Icons.person,
                                size: 45,
                                color: Colors.grey,
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.worker.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.worker.profession,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),

                            // Estado de Verificación y Nivel de Experiencia
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (data['verificationStatus'] == 'verified')
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4CAF50),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(
                                          Icons.verified,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Verificado',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (data['verificationStatus'] == 'pending')
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(
                                          Icons.schedule,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'En revisión',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (data['verificationStatus'] == 'rejected')
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade400,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(
                                          Icons.error_outline,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Rechazado',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (experienceLevel.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getLevelColor(experienceLevel).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _getLevelColor(experienceLevel),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _getLevelIcon(experienceLevel),
                                          size: 14,
                                          color: _getLevelColor(experienceLevel),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          experienceLevel,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: _getLevelColor(experienceLevel),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 8),
                            const SizedBox(height: 8),
                            StreamBuilder<Map<String, dynamic>>(
                              stream:
                                  LocationService.calculateWorkerRatingStream(
                                    widget.worker.id,
                                  ),
                              builder: (context, snapshot) {
                                final ratingData =
                                    snapshot.data ??
                                    {'rating': 0.0, 'reviews': 0};
                                final rating = (ratingData['rating'] as num)
                                    .toDouble();
                                final reviews = ratingData['reviews'] as int;

                                return Row(
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      size: 16,
                                      color: Colors.amber,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      rating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '($reviews)',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            const SizedBox(height: 8),
                            // Sección de Calificación del Usuario
                            Consumer<AuthService>(
                              builder: (context, auth, _) {
                                final currentUser = auth.currentUser;
                                if (currentUser == null) {
                                  // Si no hay sesión, mostrar botón genérico o nada
                                  return const SizedBox.shrink();
                                }

                                return StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('feedback')
                                      .where(
                                        'userId',
                                        isEqualTo: currentUser.uid,
                                      )
                                      .where(
                                        'workerId',
                                        isEqualTo: widget.worker.id,
                                      )
                                      .limit(1)
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    double myRating = 0;
                                    if (snapshot.hasData &&
                                        snapshot.data!.docs.isNotEmpty) {
                                      final data =
                                          snapshot.data!.docs.first.data()
                                              as Map<String, dynamic>;
                                      myRating = (data['rating'] as num)
                                          .toDouble();
                                    }

                                    return GestureDetector(
                                      onTap: _handleRating,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            myRating > 0
                                                ? 'Tu Calificación'
                                                : 'Calificar',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: myRating > 0
                                                  ? const Color(0xFF001BB7)
                                                  : Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: List.generate(5, (index) {
                                              return Icon(
                                                index < myRating
                                                    ? Icons.star
                                                    : Icons.star_border,
                                                size: 20,
                                                color: Colors.amber,
                                              );
                                            }),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, thickness: 1),

                // Sección de Precio
                if (price.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Precio',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Desde',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '$currency $price',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0033CC),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                const Divider(height: 1, thickness: 1),

                // Sobre el profesional
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sobre el profesional',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // Disponibilidad
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Disponibilidad',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                            color: Colors.grey[700],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            availability,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, thickness: 1),

                // Servicios
                if (services.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Servicios',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: services.take(6).map((service) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(16),
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
                      ],
                    ),
                  ),

                if (services.isNotEmpty) const Divider(height: 1, thickness: 1),

                // Portafolio
                if (portfolioImagesList.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Portafolio',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 1,
                              ),
                          itemCount: portfolioImagesList.length,
                          itemBuilder: (context, index) {
                            final imageUrl = portfolioImagesList[index]
                                .toString();
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[200],
                                    child: const Icon(
                                      Icons.broken_image,
                                      color: Colors.grey,
                                    ),
                                  );
                                },
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        color: Colors.grey[200],
                                        child: const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    },
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),
                
                if (portfolioImagesList.isNotEmpty) 
                  const Divider(height: 1, thickness: 1),

                // Videos del Portafolio
                if (portfolioVideosList.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.video_library,
                              color: Color(0xFFFF6F00),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Videos de Trabajo',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 0.8,
                              ),
                          itemCount: portfolioVideosList.length,
                          itemBuilder: (context, index) {
                            final videoUrl = portfolioVideosList[index].toString();
                            return _VideoThumbnailPlayer(
                              videoUrl: videoUrl,
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),
                const Divider(height: 1, thickness: 1),

                // Sección de Trabajadores Similares
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 24,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF001BB7), Color(0xFF0033CC)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Trabajadores Similares',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF212121),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSimilarWorkersVertical(),
                    ],
                  ),
                ),

                const SizedBox(height: 100),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomButtons(),
        );
      },
    );
  }

  // Bottom buttons with gradients
  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Botón Llamar con degradado azul
            _buildActionButton(
              icon: Icons.phone,
              label: 'Llamar',
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF448AFF),
                  Color(0xFF001BB7),
                ], // Azul más claro a oscuro
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              textColor: Colors.white,
              onPressed: () {
                if (widget.worker.phone.isNotEmpty) {
                  launchUrl(
                    Uri.parse('tel:${widget.worker.phone}'),
                    mode: LaunchMode.externalApplication,
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Número de teléfono no disponible'),
                    ),
                  );
                }
              },
            ),
            const SizedBox(width: 12),

            // Botón WhatsApp (Central y destacado)
            Expanded(
              flex: 2,
              child: _buildActionButton(
                icon: Icons.chat,
                label: 'WhatsApp',
                gradient: const LinearGradient(
                  colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                textColor: Colors.white,
                onPressed: () async {
                  if (widget.worker.phone.isNotEmpty) {
                    String phone = widget.worker.phone
                        .replaceAll(' ', '')
                        .replaceAll('-', '')
                        .replaceAll('(', '')
                        .replaceAll(')', '');

                    if (!phone.startsWith('+')) {
                      phone = '+591$phone';
                    }

                    final whatsappUrl = Uri.parse(
                      'https://wa.me/$phone?text=Hola, vi tu perfil en Job Chasky y me interesa tu servicio.',
                    );

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
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Número de teléfono no disponible'),
                      ),
                    );
                  }
                },
                isLarge: true,
              ),
            ),
            const SizedBox(width: 12),

            // Botón Contactar con degradado azul
            _buildActionButton(
              icon: Icons.chat_bubble_outline,
              label: 'Contactar\nmediante app',
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF448AFF),
                  Color(0xFF001BB7),
                ], // Azul más claro a oscuro
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              textColor: Colors.white,
              onPressed: () async {
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
                  final userIds = [currentUser.uid, widget.worker.id];
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

                  if (chatId != null && mounted) {
                    Modular.to.pushNamed(
                      '/worker/chat-detail',
                      arguments: {
                        'chatId': chatId,
                        'otherUserId': widget.worker.id,
                        'otherUserName': widget.worker.name,
                        'otherUserPhoto': widget.worker.photoUrl,
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
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Helper method to build action buttons with consistent styling
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
    Color? borderColor,
    Color? textColor,
    Gradient? gradient,
    bool isLarge = false,
  }) {
    return Expanded(
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: color,
          gradient: gradient,
          border: borderColor != null
              ? Border.all(color: borderColor, width: 1.5)
              : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: gradient != null
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: isLarge ? 24 : 20, color: textColor),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isLarge ? 13 : 11,
                    fontWeight: isLarge ? FontWeight.w600 : FontWeight.w500,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build similar workers section with VERTICAL scroll
  Widget _buildSimilarWorkersVertical() {
    final authService = Provider.of<AuthService>(context);
    final currentUserId = authService.currentUser?.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final workers = snapshot.data!.docs;

        // Filtrar trabajadores similares
        final similarWorkers = workers
            .where((doc) {
              if (doc.id == widget.worker.id || doc.id == currentUserId) {
                return false;
              }

              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] as String?;
              if (name == null || name.isEmpty || name.trim().isEmpty) {
                return false;
              }

              final professions = data['professions'] as List<dynamic>?;
              final workerCategories = widget.worker.categories
                  .map((e) => e.toLowerCase())
                  .toSet();

              if (professions != null && professions.isNotEmpty) {
                for (var prof in professions) {
                  final profMap = prof as Map<String, dynamic>?;
                  final category = profMap?['category']
                      ?.toString()
                      .toLowerCase();
                  if (category != null && workerCategories.contains(category)) {
                    return true;
                  }
                }
              }

              return false;
            })
            .take(8)
            .toList();

        if (similarWorkers.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'No hay trabajadores similares disponibles',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ),
          );
        }

        // VERTICAL scroll usando GridView
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            childAspectRatio: 0.62,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: similarWorkers.length,
          itemBuilder: (context, index) {
            final workerDoc = similarWorkers[index];
            final data = workerDoc.data() as Map<String, dynamic>;

            final name = data['name'] as String? ?? '';
            final photoUrl = data['photoUrl'] as String?;
            final workerLocation = data['location'] as Map<String, dynamic>?;

            // Obtener profesión
            String profession =
                (data['profession'] as String? ??
                        (data['profile']
                                as Map<String, dynamic>?)?['profession']
                            as String? ??
                        '')
                    .toString();
            final professionsData =
                (data['professions'] as List<dynamic>?) ??
                ((data['profile'] as Map<String, dynamic>?)?['professions']
                    as List<dynamic>?);
            if (profession.isEmpty &&
                professionsData != null &&
                professionsData.isNotEmpty) {
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
              if (allSubcategories.isNotEmpty) {
                profession = allSubcategories.take(2).join(' • ');
              }
            }

            final price = (data['price']?.toString() ?? '').trim();

            return StreamBuilder<Map<String, dynamic>>(
              stream: LocationService.calculateWorkerRatingStream(workerDoc.id),
              builder: (context, ratingSnapshot) {
                final ratingData =
                    ratingSnapshot.data ?? {'rating': 0.0, 'reviews': 0};

                return _buildCompactWorkerCard(
                  workerId: workerDoc.id,
                  name: name,
                  profession: profession,
                  rating: (ratingData['rating'] as num).toDouble(),
                  reviews: ratingData['reviews'] as int,
                  price: price,
                  photoUrl: photoUrl,
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
  }

  /// Build compact worker card for similar workers (vertical grid)
  Widget _buildCompactWorkerCard({
    required String workerId,
    required String name,
    required String profession,
    required double rating,
    required int reviews,
    required String price,
    String? photoUrl,
    required String phone,
    required double latitude,
    required double longitude,
    required List<String> categories,
  }) {
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
            // Image
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
                  ? Icon(Icons.person, size: 50, color: Colors.grey[400])
                  : null,
            ),
            // Content
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
                        color: Color(0xFF212121),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (profession.isNotEmpty &&
                        profession != 'Sin profesión especificada')
                      Text(
                        profession,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF616161),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '($reviews)',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (price.isNotEmpty)
                      Text(
                        'Bs $price',
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

  // Helper methods para nivel de experiencia
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

// Widget para reproducir videos en el portafolio
class _VideoThumbnailPlayer extends StatefulWidget {
  final String videoUrl;

  const _VideoThumbnailPlayer({
    required this.videoUrl,
  });

  @override
  State<_VideoThumbnailPlayer> createState() => _VideoThumbnailPlayerState();
}

class _VideoThumbnailPlayerState extends State<_VideoThumbnailPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      await _controller.initialize();
      _controller.setLooping(true);

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
      debugPrint('Video URL: ${widget.videoUrl}');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _isPlaying = false;
      } else {
        _controller.play();
        _isPlaying = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red.shade300,
              size: 40,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Error al cargar video',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6F00)),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _togglePlayPause,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video player
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            ),
            
            // Overlay con botón play/pause
            if (!_isPlaying)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
            
            // Indicador de video premium en la esquina
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF6F00), Color(0xFFFFC107)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.play_circle_filled,
                      color: Colors.white,
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Video',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Duración del video en la esquina inferior
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatDuration(_controller.value.duration),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
