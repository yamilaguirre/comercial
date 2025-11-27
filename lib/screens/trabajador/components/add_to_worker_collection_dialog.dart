import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/theme.dart';
import '../../../services/worker_saved_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../models/saved_collection_model.dart';
import 'create_worker_collection_dialog.dart';

class AddToWorkerCollectionDialog extends StatefulWidget {
  final String workerId;

  const AddToWorkerCollectionDialog({super.key, required this.workerId});

  @override
  State<AddToWorkerCollectionDialog> createState() =>
      _AddToWorkerCollectionDialogState();
}

class _AddToWorkerCollectionDialogState
    extends State<AddToWorkerCollectionDialog> {
  final WorkerSavedService _savedService = WorkerSavedService();
  List<SavedCollection> _collections = [];
  Set<String> _selectedCollectionIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid ?? '';

    setState(() => _isLoading = true);

    try {
      // Usamos first para obtener el valor actual del stream
      final collections = await _savedService.getUserCollections(userId).first;

      // Obtener colecciones que ya contienen este trabajador
      final collectionsWithWorker = await _savedService
          .getCollectionsWithWorker(userId, widget.workerId);

      final selectedIds = collectionsWithWorker.map((c) => c.id).toSet();

      if (mounted) {
        setState(() {
          _collections = collections;
          _selectedCollectionIds = selectedIds;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading collections: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar colecciones: $e')),
        );
      }
    }
  }

  Future<void> _createNewCollection() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const CreateWorkerCollectionDialog(),
    );

    if (name == null || name.isEmpty) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid ?? '';

    final collectionId = await _savedService.createCollection(userId, name);

    if (collectionId != null) {
      // Agregar el trabajador a la nueva colección
      await _savedService.addWorkerToCollection(collectionId, widget.workerId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Colección "$name" creada y trabajador agregado'),
          ),
        );
        _loadCollections();
      }
    }
  }

  Future<void> _save() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid ?? '';

    // Obtener colecciones que tenían el trabajador antes
    final previousCollections = await _savedService.getCollectionsWithWorker(
      userId,
      widget.workerId,
    );
    final previousIds = previousCollections.map((c) => c.id).toSet();

    // Agregar a nuevas colecciones
    for (final collectionId in _selectedCollectionIds) {
      if (!previousIds.contains(collectionId)) {
        await _savedService.addWorkerToCollection(
          collectionId,
          widget.workerId,
        );
      }
    }

    // Quitar de colecciones deseleccionadas
    for (final collectionId in previousIds) {
      if (!_selectedCollectionIds.contains(collectionId)) {
        await _savedService.removeWorkerFromCollection(
          collectionId,
          widget.workerId,
        );
      }
    }

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Guardar en colección'),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_collections.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'No tienes colecciones aún',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _collections.length,
                        itemBuilder: (context, index) {
                          final collection = _collections[index];
                          final isSelected = _selectedCollectionIds.contains(
                            collection.id,
                          );

                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedCollectionIds.add(collection.id);
                                } else {
                                  _selectedCollectionIds.remove(collection.id);
                                }
                              });
                            },
                            title: Text(collection.name),
                            subtitle: Text(
                              '${collection.propertyCount} ${collection.propertyCount == 1 ? 'trabajador' : 'trabajadores'}',
                            ),
                            activeColor: Styles.primaryColor,
                          );
                        },
                      ),
                    ),
                  const Divider(),
                  ListTile(
                    leading: Icon(Icons.add, color: Styles.primaryColor),
                    title: Text(
                      'Crear nueva colección',
                      style: TextStyle(
                        color: Styles.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: _createNewCollection,
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: Styles.primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
