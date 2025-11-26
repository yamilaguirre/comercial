import 'package:flutter/material.dart';
import '../../../theme/theme.dart';
// Asumo que estos archivos existen en tu proyecto
import '../../../models/property.dart';
import '../../../core/utils/amenity_helper.dart';
import '../../../core/utils/property_constants.dart';

// Define las variantes de tarjeta para su reutilización
enum PropertyCardStyle { detailed, grid, small }

class PropertyCardListItem extends StatelessWidget {
  final Property property;
  final PropertyCardStyle style;
  final VoidCallback onTap;

  const PropertyCardListItem({
    super.key,
    required this.property,
    required this.onTap,
    this.style = PropertyCardStyle.detailed,
  });

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case PropertyCardStyle.detailed:
        return _buildDetailedCard(context);
      case PropertyCardStyle.grid:
        return _buildGridCard();
      case PropertyCardStyle.small:
        return _buildSmallCard();
      default:
        return _buildDetailedCard(context);
    }
  }

  // --- Implementaciones de las variantes de tarjeta ---

  // Corresponde a _buildPropertyCard (Lista horizontal grande y detallada)
  Widget _buildDetailedCard(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 300,
        margin: EdgeInsets.only(right: Styles.spacingMedium),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: Image.network(
                    property.imageUrl,
                    height: 200,
                    width: 300,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image, size: 50),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite_border,
                      size: 20,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              // Usamos Expanded para que la columna interior ocupe el espacio restante
              child: Padding(
                padding: EdgeInsets.all(Styles.spacingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.price,
                      style: TextStyles.title.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Styles.textPrimary,
                      ),
                    ),
                    SizedBox(height: Styles.spacingXSmall),
                    Text(
                      property.name,
                      style: TextStyles.body.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: Styles.spacingXSmall),
                    Text(
                      property.location,
                      style: TextStyles.caption.copyWith(
                        color: Styles.textSecondary,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: Styles.spacingSmall),

                    Row(
                      children: [
                        Icon(Icons.bed, size: 16, color: Styles.textSecondary),
                        SizedBox(width: 4),
                        Text(
                          '${property.bedrooms}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Styles.textSecondary,
                          ),
                        ),
                        SizedBox(width: 12),
                        Icon(
                          Icons.bathtub,
                          size: 16,
                          color: Styles.textSecondary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '${property.bathrooms}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Styles.textSecondary,
                          ),
                        ),
                        SizedBox(width: 12),
                        Icon(
                          Icons.square_foot,
                          size: 16,
                          color: Styles.textSecondary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '${property.area.toStringAsFixed(0)}m²',
                          style: TextStyle(
                            fontSize: 12,
                            color: Styles.textSecondary,
                          ),
                        ),
                      ],
                    ),

                    if (property.amenities.isNotEmpty) ...[
                      SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: property.amenities.take(5).map((key) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Tooltip(
                                message:
                                    PropertyConstants.amenityLabels[key] ?? key,
                                child: Icon(
                                  AmenityHelper.getIcon(key),
                                  size: 18,
                                  color: Styles.primaryColor.withOpacity(0.7),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                    const Spacer(), // Empuja los botones de acción hacia abajo
                  ],
                ),
              ),
            ),
            _buildActionButtons(), // Botones de acción en la base
          ],
        ),
      ),
    );
  }

  // Corresponde a _buildSimplePropertyCard (Usado en el Grid)
  Widget _buildGridCard() {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: Image.network(
                    property.imageUrl,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Container(height: 120, color: Colors.grey[300]),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite_border,
                      size: 16,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.price,
                      style: TextStyles.title.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Styles.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      property.name,
                      style: TextStyles.body.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.bed, size: 12, color: Styles.textSecondary),
                        Text(
                          ' ${property.bedrooms}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Styles.textSecondary,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.square_foot,
                          size: 12,
                          color: Styles.textSecondary,
                        ),
                        Text(
                          ' ${property.area.toInt()}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Styles.textSecondary,
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    if (property.amenities.isNotEmpty)
                      Row(
                        children: property.amenities.take(3).map((key) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              AmenityHelper.getIcon(key),
                              size: 14,
                              color: Styles.primaryColor.withOpacity(0.6),
                            ),
                          );
                        }).toList(),
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

  // Corresponde a _buildSmallPropertyCard (Lista horizontal pequeña "Últimas publicadas")
  Widget _buildSmallCard() {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        margin: EdgeInsets.only(right: Styles.spacingMedium),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Image.network(
                property.imageUrl,
                height: 200,
                width: 280,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Container(height: 200, color: Colors.grey[300]),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_border,
                    size: 20,
                    color: Colors.black87,
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.price,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      property.name,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget auxiliar para los botones de acción (solo usado en DetailedCard)
  Widget _buildActionButtons() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Styles.spacingMedium,
        0,
        Styles.spacingMedium,
        Styles.spacingMedium,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildActionButton(Icons.phone, 'Llamar'),
          _buildActionButton(Icons.message, 'Mensaje'),
          _buildActionButton(Icons.share, 'Compartir'),
          _buildActionButton(Icons.favorite_border, 'Guardar'),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: Styles.primaryColor),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Styles.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
