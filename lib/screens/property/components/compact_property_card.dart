import 'package:flutter/material.dart';
import '../../../theme/theme.dart';
import '../../../models/property.dart';
import '../../../core/utils/amenity_helper.dart';

class CompactPropertyCard extends StatelessWidget {
  final Property property;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;
  final bool showGoldenBorder;

  const CompactPropertyCard({
    super.key,
    required this.property,
    required this.onTap,
    this.isFavorite = false,
    this.onFavoriteToggle,
    this.showGoldenBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: showGoldenBorder
          ? _buildCardWithBorder()
          : _buildCardWithoutBorder(),
    );
  }

  Widget _buildCardWithBorder() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFF6F00), // Naranja vibrante
            Color(0xFFFFC107), // Amarillo vibrante
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFFF6F00).withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: _buildCardContent(),
      ),
    );
  }

  Widget _buildCardWithoutBorder() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: _buildCardContent(),
    );
  }

  Widget _buildCardContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // IMAGEN
        Stack(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Image.network(
                property.imageUrl,
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 100,
                    color: Colors.grey[200],
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Styles.primaryColor,
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 100,
                  color: Colors.grey[300],
                  child: const Icon(
                    Icons.image_not_supported,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
            // COMPANY LOGO (si es empresa)
            if (property.publisherType == 'company' &&
                property.companyLogo != null)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 12,
                    backgroundImage: NetworkImage(property.companyLogo!),
                    backgroundColor: Colors.white,
                    onBackgroundImageError: (exception, stackTrace) {},
                    child: const SizedBox(),
                  ),
                ),
              ),
            // FAVORITE ICON
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: onFavoriteToggle,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    size: 14,
                    color: isFavorite ? Colors.red : Colors.black87,
                  ),
                ),
              ),
            ),
          ],
        ),

        // CONTENIDO
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // PRECIO
                Text(
                  property.price,
                  style: TextStyles.title.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Styles.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),

                // NOMBRE
                Text(
                  property.name,
                  style: TextStyles.body.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),

                // UBICACIÓN
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 10,
                      color: Styles.textSecondary,
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        property.location,
                        style: TextStyle(
                          fontSize: 9,
                          color: Styles.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // CARACTERÍSTICAS (Camas, Metros)
                Row(
                  children: [
                    Icon(Icons.bed, size: 11, color: Styles.textSecondary),
                    Text(
                      ' ${property.bedrooms}',
                      style: TextStyle(
                        fontSize: 9,
                        color: Styles.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.square_foot,
                      size: 11,
                      color: Styles.textSecondary,
                    ),
                    Text(
                      ' ${property.area.toInt()}',
                      style: TextStyle(
                        fontSize: 9,
                        color: Styles.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // AMENIDADES
                if (property.amenities.isNotEmpty)
                  Row(
                    children: property.amenities.take(4).map((key) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 3),
                        child: Icon(
                          AmenityHelper.getIcon(key),
                          size: 12,
                          color: Styles.primaryColor.withOpacity(0.7),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
