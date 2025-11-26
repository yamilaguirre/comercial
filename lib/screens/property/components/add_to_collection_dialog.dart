import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/theme.dart';
import '../../../services/saved_list_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../models/saved_collection_model.dart';
import 'create_collection_dialog.dart';

class AddToCollectionDialog extends StatefulWidget {
  final String propertyId;

  const AddToCollectionDialog({super.key, required this.propertyId});

  @override
  State<AddToCollectionDialog> createState() => _AddToCollectionDialogState();
}

class _AddToCollectionDialogState extends State<AddToCollectionDialog> {
  final SavedListService _savedListService = SavedListService();
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

    final collections = await _savedListService
        .getUserCollections(userId)
        .first;

    // Obtener colecciones que ya contienen esta propiedad
    final collectionsWithProperty = await _savedListService
        .getCollectionsWithProperty(userId, widget.propertyId);

    final selectedIds = collectionsWithProperty.map((c) => c.id).toSet();

    if (mounted) {
      setState(() {
        _collections = collections;
        _selectedCollectionIds = selectedIds;
        _isLoading = false;
      });
    }
  }

  Future<void> _createNewCollection() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const CreateCollectionDialog(),
    );

    if (name == null || name.isEmpty) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid ?? '';

    final collectionId = await _savedListService.createCollection(userId, name);

    if (collectionId != null) {
      // Agregar la propiedad a la nueva colección
      await _savedListService.addPropertyToCollection(
        collectionId,
        widget.propertyId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Colección "$name" creada y propiedad agregada'),
          ),
        );
        _loadCollections();
      }
    }
  }

  Future<void> _save() async {
    // Obtener colecciones que tenían la propiedad antes
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid ?? '';

    final previousCollections = await _savedListService
        .getCollectionsWithProperty(userId, widget.propertyId);
    final previousIds = previousCollections.map((c) => c.id).toSet();

    // Agregar a nuevas colecciones
    for (final collectionId in _selectedCollectionIds) {
      if (!previousIds.contains(collectionId)) {
        await _savedListService.addPropertyToCollection(
          collectionId,
          widget.propertyId,
        );
      }
    }

    // Quitar de colecciones deseleccionadas
    for (final collectionId in previousIds) {
      if (!_selectedCollectionIds.contains(collectionId)) {
        await _savedListService.removePropertyFromCollection(
          collectionId,
          widget.propertyId,
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
                              '${collection.propertyCount} ${collection.propertyCount == 1 ? 'propiedad' : 'propiedades'}',
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
