import 'package:flutter/material.dart';
import '../../../models/property.dart';
import '../../../core/utils/amenity_helper.dart';

class PropertyCard extends StatelessWidget {
  final Property property;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onTap;
  final bool showGoldenBorder;

  const PropertyCard({
    super.key,
    required this.property,
    required this.isFavorite,
    required this.onFavoriteToggle,
    required this.onTap,
    this.showGoldenBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - 48) / 2;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: cardWidth * 1.35,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: showGoldenBorder
              ? Border.all(color: const Color(0xFFFFD700), width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildImageSection(cardWidth),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          property.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 12,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                property.location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _buildCompactInfo(),
                        const Spacer(),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1976D2).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            property.price,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1976D2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection(double cardWidth) {
    return Stack(
      children: [
        Container(
          height: cardWidth * 0.65,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            image: property.imageUrl.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(property.imageUrl),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: property.imageUrl.isEmpty
              ? Center(
                  child: Icon(Icons.image, size: 32, color: Colors.grey[400]),
                )
              : null,
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 30,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.3)],
              ),
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: GestureDetector(
            onTap: onFavoriteToggle,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? Colors.red : Colors.grey[700],
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactInfo() {
    final infoItems = <Widget>[];

    if (property.bedrooms != null && property.bedrooms! > 0) {
      infoItems.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bed_outlined, size: 12, color: const Color(0xFF1976D2)),
            const SizedBox(width: 2),
            Text(
              '${property.bedrooms}',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
            ),
          ],
        ),
      );
    }

    if (property.area != null && property.area! > 0) {
      infoItems.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.square_foot, size: 12, color: const Color(0xFF1976D2)),
            const SizedBox(width: 2),
            Text(
              '${property.area}m²',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
            ),
          ],
        ),
      );
    }

    if (property.amenities != null && property.amenities!.isNotEmpty) {
      final amenitiesList = property.amenities!.take(3).toList();
      for (final amenity in amenitiesList) {
        final amenityIcon = AmenityHelper.getAmenityIcon(amenity);
        final amenityColor = AmenityHelper.getAmenityColor(amenity);
        
        infoItems.add(
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: amenityColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(amenityIcon, size: 10, color: amenityColor),
          ),
        );
      }
    }

    if (infoItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: infoItems,
    );
  }
}
