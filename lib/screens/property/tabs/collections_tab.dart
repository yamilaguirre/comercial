import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import '../../../theme/theme.dart';
import '../../../models/saved_collection_model.dart';
import '../../../services/saved_list_service.dart';
import '../components/collection_card.dart';
import '../components/create_collection_dialog.dart';
import '../components/edit_collection_dialog.dart';

class CollectionsTab extends StatefulWidget {
  final String userId;
  final VoidCallback onCollectionChanged;

  const CollectionsTab({
    super.key,
    required this.userId,
    required this.onCollectionChanged,
  });

  @override
  State<CollectionsTab> createState() => _CollectionsTabState();
}

class _CollectionsTabState extends State<CollectionsTab> {
  final SavedListService _savedListService = SavedListService();

  Future<void> _createCollection() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const CreateCollectionDialog(),
    );

    if (name == null || name.isEmpty) return;

    final collectionId = await _savedListService.createCollection(
      widget.userId,
      name,
    );

    if (collectionId != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Colección "$name" creada')));
      widget.onCollectionChanged();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al crear la colección')),
      );
    }
  }

  Future<void> _editCollection(SavedCollection collection) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => EditCollectionDialog(currentName: collection.name),
    );

    if (newName == null || newName.isEmpty || newName == collection.name) {
      return;
    }

    final success = await _savedListService.updateCollectionName(
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
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
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

    final success = await _savedListService.deleteCollection(collection.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Colección eliminada' : 'Error al eliminar la colección',
          ),
        ),
      );
      if (success) widget.onCollectionChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Botón crear colección
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

        // Lista de colecciones
        Expanded(
          child: StreamBuilder<List<SavedCollection>>(
            stream: _savedListService.getUserCollections(widget.userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Styles.primaryColor),
                );
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
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
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
                        'Crea una para organizar tus propiedades',
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
                  return CollectionCard(
                    collection: collection,
                    onTap: () {
                      Modular.to.pushNamed(
                        '/property/collection-detail',
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
