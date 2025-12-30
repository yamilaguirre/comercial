import 'package:flutter/material.dart';
import '../../../models/property.dart';
import 'property_card.dart';

class PropertyCarousel extends StatelessWidget {
  final String title;
  final List<Property> properties;
  final Color primaryColor;
  final Color secondaryColor;
  final String badgeText;
  final IconData badgeIcon;
  final Set<String> savedPropertyIds;
  final Function(Property) onFavoriteToggle;
  final Function(Property) onTap;
  final Map<String, String>? companyLogos; // propertyId -> companyLogo

  const PropertyCarousel({
    super.key,
    required this.title,
    required this.properties,
    required this.primaryColor,
    required this.secondaryColor,
    required this.badgeText,
    required this.badgeIcon,
    required this.savedPropertyIds,
    required this.onFavoriteToggle,
    required this.onTap,
    this.companyLogos,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.03;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título de la sección
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: (screenWidth * 0.045).clamp(16.0, 24.0),
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 2.5,
                width: screenWidth * 0.12,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Carrusel horizontal
        SizedBox(
          height: screenWidth * 0.55, // Altura reducida
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            itemCount: properties.length,
            itemBuilder: (context, index) {
              final property = properties[index];
              final cardWidth = screenWidth * 0.45; // Reducido de 70% a 45%

              return Container(
                width: cardWidth,
                margin: EdgeInsets.only(
                  right: index < properties.length - 1 ? screenWidth * 0.03 : 0,
                ),
                child: PropertyCard(
                  property: property,
                  isFavorite: savedPropertyIds.contains(property.id),
                  onFavoriteToggle: () => onFavoriteToggle(property),
                  onTap: () => onTap(property),
                  showGoldenBorder: true,
                  companyLogo: companyLogos?[property.id],
                ),
              );
            },
          ),
        ),
        SizedBox(height: screenWidth * 0.04),
      ],
    );
  }
}
