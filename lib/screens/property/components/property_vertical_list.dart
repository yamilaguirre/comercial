import 'package:flutter/material.dart';
import '../../../models/property.dart';
import 'property_card.dart';

class PropertyVerticalList extends StatefulWidget {
  final String title;
  final List<Property> properties;
  final Color titleColor;
  final Set<String> savedPropertyIds;
  final Function(Property) onFavoriteToggle;
  final Function(Property) onTap;
  final VoidCallback? onLoadMore;
  final bool hasMore;
  final bool isLoading;
  final Map<String, String>? companyLogos; // propertyId -> companyLogo

  const PropertyVerticalList({
    super.key,
    required this.title,
    required this.properties,
    this.titleColor = const Color(0xFF2C3E50),
    required this.savedPropertyIds,
    required this.onFavoriteToggle,
    required this.onTap,
    this.onLoadMore,
    this.hasMore = false,
    this.isLoading = false,
    this.companyLogos,
  });

  @override
  State<PropertyVerticalList> createState() => _PropertyVerticalListState();
}

class _PropertyVerticalListState extends State<PropertyVerticalList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      // Cuando llega al 80% del scroll, cargar más
      if (widget.hasMore && !widget.isLoading && widget.onLoadMore != null) {
        widget.onLoadMore!();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.03;
    final crossAxisSpacing = screenWidth * 0.025;
    final mainAxisSpacing = screenWidth * 0.025;

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
                widget.title,
                style: TextStyle(
                  fontSize: (screenWidth * 0.045).clamp(16.0, 24.0),
                  fontWeight: FontWeight.bold,
                  color: widget.titleColor,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 2.5,
                width: screenWidth * 0.12,
                decoration: BoxDecoration(
                  color: widget.titleColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Grid de propiedades con scroll infinito
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: GridView.builder(
            controller: _scrollController,
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio:
                  0.82, // Ajustado para coincidir con carrusel (45% ancho, 55% altura del ancho)
              crossAxisSpacing: crossAxisSpacing,
              mainAxisSpacing: mainAxisSpacing,
            ),
            itemCount: widget.properties.length + (widget.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              // Si es el último item y hay más para cargar, mostrar loading
              if (index == widget.properties.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final property = widget.properties[index];
              return PropertyCard(
                property: property,
                isFavorite: widget.savedPropertyIds.contains(property.id),
                onFavoriteToggle: () => widget.onFavoriteToggle(property),
                onTap: () => widget.onTap(property),
                showGoldenBorder: false,
                companyLogo: widget.companyLogos?[property.id],
              );
            },
          ),
        ),

        // Indicador de carga al final
        if (widget.isLoading)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}
