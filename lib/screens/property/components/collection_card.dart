import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/saved_collection_model.dart';
import '../../../theme/theme.dart';

class CollectionCard extends StatelessWidget {
  final SavedCollection collection;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const CollectionCard({
    super.key,
    required this.collection,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  Future<String?> _getCoverImage() async {
    if (collection.propertyIds.isEmpty) return null;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('properties')
          .doc(collection.propertyIds.first)
          .get();

      if (!doc.exists) return null;

      final data = doc.data();
      final images = data?['imageUrls'] as List<dynamic>?;
      if (images != null && images.isNotEmpty) {
        return images.first as String;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Imagen de portada
            FutureBuilder<String?>(
              future: _getCoverImage(),
              builder: (context, snapshot) {
                return ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  child: snapshot.hasData && snapshot.data != null
                      ? Image.network(
                          snapshot.data!,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildPlaceholder();
                          },
                        )
                      : _buildPlaceholder(),
                );
              },
            ),

            // Información
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      collection.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${collection.propertyCount} ${collection.propertyCount == 1 ? 'propiedad' : 'propiedades'}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),

            // Botones de acción
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, size: 20, color: Colors.grey[600]),
                  onPressed: onEdit,
                  tooltip: 'Editar',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                  onPressed: onDelete,
                  tooltip: 'Eliminar',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 80,
      height: 80,
      color: Colors.grey[200],
      child: Icon(Icons.home_work, size: 40, color: Colors.grey[400]),
    );
  }
}
