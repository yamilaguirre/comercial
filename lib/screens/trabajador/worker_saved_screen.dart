import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../theme/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/location_service.dart';
import 'package:url_launcher/url_launcher.dart';

class WorkerSavedScreen extends StatefulWidget {
  const WorkerSavedScreen({super.key});

  @override
  State<WorkerSavedScreen> createState() => _WorkerSavedScreenState();
}

class _WorkerSavedScreenState extends State<WorkerSavedScreen> {
  String selectedTab = 'Todo Guardado';
  int selectedFilter = 0;

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final currentUserId = authService.currentUser?.uid;

    if (currentUserId == null) {
      return Scaffold(
        body: Center(
          child: Text('Debes iniciar sesión'),
        ),
      );
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
          // Tabs: Todo Guardado / Mis Colecciones
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Styles.spacingMedium,
              vertical: Styles.spacingSmall,
            ),
            child: Row(
              children: [
                Expanded(child: _buildTabButton('Todo Guardado')),
                SizedBox(width: Styles.spacingSmall),
                Expanded(child: _buildTabButton('Mis Colecciones')),
              ],
            ),
          ),

          // Filtros: Guardados, Contactados, Por contactar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: Styles.spacingMedium),
            child: Row(
              children: [
                _buildFilterChip(Icons.favorite, 'Guardados', 0, 0),
                SizedBox(width: Styles.spacingSmall),
                _buildFilterChip(
                  Icons.check_circle_outline,
                  'Contactados',
                  1,
                  0,
                ),
                SizedBox(width: Styles.spacingSmall),
                _buildFilterChip(Icons.phone_outlined, 'P...', 2, 0),
              ],
            ),
          ),

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
                    favoriteWorkers.map((workerId) =>
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(workerId)
                            .get()),
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

                    return ListView.builder(
                      padding: EdgeInsets.symmetric(
                          horizontal: Styles.spacingMedium),
                      itemCount: workers.length,
                      itemBuilder: (context, index) {
                        final workerData =
                            workers[index].data() as Map<String, dynamic>;
                        return _buildWorkerCard(
                          workerId: workers[index].id,
                          workerData: workerData,
                          currentUserId: currentUserId,
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

  Widget _buildTabButton(String title) {
    final isSelected = selectedTab == title;
    return GestureDetector(
      onTap: () => setState(() => selectedTab = title),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: Styles.spacingSmall),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF5F5F5) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyles.body.copyWith(
            color: isSelected ? Styles.textPrimary : Styles.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(IconData icon, String label, int index, int count) {
    final isSelected = selectedFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedFilter = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? Styles.primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? Styles.primaryColor : const Color(0xFFE5E7EB),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : const Color(0xFF6B7280),
                size: 18,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF374151),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.25)
                        : Styles.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Styles.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkerCard({
    required String workerId,
    required Map<String, dynamic> workerData,
    required String currentUserId,
  }) {
    final name = workerData['name'] ?? 'Sin nombre';
    final profession = workerData['profession'] ?? 'Sin profesión';
    final photoUrl = workerData['photoUrl'];
    final phone = workerData['phone'] ?? '';
    final services =
        (workerData['services'] as List<dynamic>?)?.cast<String>() ?? [];

    // USAR STREAMBUILDER EN LUGAR DE FUTUREBUILDER (igual que en home_work_screen)
    return StreamBuilder<Map<String, dynamic>>(
      stream: LocationService.calculateWorkerRatingStream(workerId),
      builder: (context, ratingSnapshot) {
        final ratingData =
            ratingSnapshot.data ?? {'rating': 0.0, 'reviews': 0};
        final rating = (ratingData['rating'] as num).toDouble();
        final reviewCount = ratingData['reviews'] as int;

        return Container(
          margin: EdgeInsets.only(bottom: Styles.spacingMedium),
          padding: EdgeInsets.all(Styles.spacingMedium),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con foto, nombre y favorito
              Row(
                children: [
                  // Avatar
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[200],
                    ),
                    child: photoUrl != null
                        ? ClipOval(
                            child: Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(Icons.person,
                                      size: 35, color: Colors.grey[600]),
                            ),
                          )
                        : Icon(Icons.person, size: 35, color: Colors.grey[600]),
                  ),

                  const SizedBox(width: 12),

                  // Nombre y profesión
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profession,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Icono de favorito
                  IconButton(
                    icon: const Icon(Icons.favorite, color: Colors.red, size: 24),
                    onPressed: () => _toggleFavorite(workerId),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Rating y badge profesional
              Row(
                children: [
                  ...List.generate(
                    5,
                    (index) {
                      if (index < rating.floor()) {
                        return const Icon(
                          Icons.star,
                          color: Color(0xFFFFC107),
                          size: 16,
                        );
                      } else if (index < rating) {
                        return const Icon(
                          Icons.star_half,
                          color: Color(0xFFFFC107),
                          size: 16,
                        );
                      } else {
                        return Icon(
                          Icons.star_border,
                          color: Colors.grey[400],
                          size: 16,
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 6),
                  Text(
                    reviewCount > 0 ? '($reviewCount)' : '(Sin calificar)',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF616161),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (workerData['isProfessional'] == true)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Styles.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Profesional',
                        style: TextStyle(
                          fontSize: 11,
                          color: Styles.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Precio, distancia y rating
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Desde',
                        style:
                            TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      Text(
                        'Bs ${workerData['price'] ?? 0}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Styles.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (workerData['distance'] != null)
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'A ${workerData['distance']} km',
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black54),
                        ),
                      ],
                    ),
                  const SizedBox(width: 16),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 16, color: Color(0xFFFFC107)),
                      const SizedBox(width: 4),
                      Text(
                        '${rating.toStringAsFixed(1)} ($reviewCount)',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Tags de servicios
              if (services.isNotEmpty)
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
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        service,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF374151),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 16),

              // Botones de acción
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _makePhoneCall(phone),
                      icon: const Icon(Icons.phone, size: 18),
                      label: const Text('Llamar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: const BorderSide(
                          color: Color(0xFFE5E7EB),
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _showRatingDialog(
                            workerId,
                            name,
                            rating,
                          ),
                      icon: const Icon(Icons.star_outline, size: 18),
                      label: const Text('Calificar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Styles.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleFavorite(String workerId) async {
    final authService = context.read<AuthService>();
    final currentUserId = authService.currentUser?.uid;

    if (currentUserId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .update({
            'favoriteWorkers': FieldValue.arrayRemove([workerId]),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Eliminado de favoritos')),
        );
      }
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
    }
  }

  Future<void> _showRatingDialog(
    String workerId,
    String workerName,
    double currentRating,
  ) async {
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

  Future<void> _makePhoneCall(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este trabajador no tiene teléfono registrado'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo realizar la llamada'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}