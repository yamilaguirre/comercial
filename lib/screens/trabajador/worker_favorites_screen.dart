import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_modular/flutter_modular.dart';
import '../../theme/theme.dart';
import '../../services/worker_saved_service.dart';
import '../../providers/auth_provider.dart';
import '../../models/saved_collection_model.dart';
import 'components/worker_collection_card.dart';
import 'components/create_worker_collection_dialog.dart';
import 'components/edit_worker_collection_dialog.dart';
import 'components/worker_card_compact.dart';
import 'worker_location_search_screen.dart'; // Para WorkerData

class WorkerFavoritesScreen extends StatefulWidget {
  const WorkerFavoritesScreen({super.key});

  @override
  State<WorkerFavoritesScreen> createState() => _WorkerFavoritesScreenState();
}

class _WorkerFavoritesScreenState extends State<WorkerFavoritesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final WorkerSavedService _savedService = WorkerSavedService();
  int _savedCount = 0;
  int _contactedCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCounts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCounts() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid ?? '';

    final count = await _savedService.getTotalSavedCount(userId);
    final contacted = await _savedService.getContactedCount(userId);

    if (mounted) {
      setState(() {
        _savedCount = count;
        _contactedCount = contacted;
      });
    }
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
          preferredSize: const Size.fromHeight(120),
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
              const SizedBox(height: 16),

              // Contadores
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildCounter(
                      icon: Icons.favorite,
                      label: 'Guardados',
                      count: _savedCount,
                      color: Styles.primaryColor,
                      isSelected: true,
                    ),
                    const SizedBox(width: 12),
                    _buildCounter(
                      icon: Icons.chat_bubble_outline,
                      label: 'Contactados',
                      count: _contactedCount,
                      color: Colors.grey,
                      isSelected: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
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
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    required bool isSelected,
  }) {
    return Container(
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
    );
  }

  Widget _buildAllSavedTab(String userId) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _savedService.getAllSavedWorkers(userId),
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
                Icon(Icons.favorite_border, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No tienes trabajadores guardados',
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

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: workers.length,
          itemBuilder: (context, index) {
            final worker = workers[index];
            return WorkerCardCompact(
              worker: worker,
              onTap: () {
                // Navegar al perfil público
                // Construir WorkerData desde el mapa
                final workerData = WorkerData(
                  id: worker['id'],
                  name: worker['name'] ?? 'Usuario',
                  profession: worker['profession'] ?? 'Profesional',
                  categories: [], // TODO: Parse categories if needed
                  latitude: 0, // No needed for display
                  longitude: 0,
                  photoUrl: worker['photoUrl'],
                  rating: (worker['rating'] ?? 0.0).toDouble(),
                  phone: worker['phoneNumber'] ?? '',
                  price: (worker['price']?.toString() ?? '').trim(),
                );

                Modular.to.pushNamed(
                  '/worker/public-profile',
                  arguments: workerData,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCollectionsTab(String userId) {
    return Column(
      children: [
        // Botón crear colección
        Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            onPressed: _createCollection,
            icon: const Icon(Icons.add),
            label: const Text('Crear nueva colección'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Styles.primaryColor,
              side: BorderSide(color: Styles.primaryColor),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),

        // Lista de colecciones
        Expanded(
          child: StreamBuilder<List<SavedCollection>>(
            stream: _savedService.getUserCollections(userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error al cargar colecciones',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final collections = snapshot.data ?? [];

              if (collections.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_open,
                        size: 80,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No tienes colecciones',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Crea una para organizar tus trabajadores favoritos',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
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
}
