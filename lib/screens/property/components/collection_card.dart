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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 130,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Imagen de fondo con FutureBuilder
            Positioned.fill(
              child: FutureBuilder<String?>(
                future: _getCoverImage(),
                builder: (context, snapshot) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: snapshot.hasData && snapshot.data != null
                        ? Image.network(
                            snapshot.data!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildPlaceholder();
                            },
                          )
                        : _buildPlaceholder(),
                  );
                },
              ),
            ),

            // Gradiente overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
            ),

            // Contenido
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Botones de acción
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.edit,
                              size: 18,
                              color: Colors.white,
                            ),
                            onPressed: onEdit,
                            tooltip: 'Editar',
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(
                              minWidth: 30,
                              minHeight: 30,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.delete,
                              size: 18,
                              color: Colors.white,
                            ),
                            onPressed: onDelete,
                            tooltip: 'Eliminar',
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(
                              minWidth: 30,
                              minHeight: 30,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Información
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            collection.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.home_work,
                                size: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '${collection.propertyCount} ${collection.propertyCount == 1 ? 'propiedad' : 'propiedades'}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
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

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Styles.primaryColor.withOpacity(0.3),
            Styles.primaryColor.withOpacity(0.6),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.folder_special,
          size: 48,
          color: Colors.white.withOpacity(0.7),
        ),
      ),
    );
  }
}
