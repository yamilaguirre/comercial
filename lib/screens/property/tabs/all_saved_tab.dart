import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import '../../../theme/theme.dart';
import '../../../models/property.dart';
import '../../../models/contact_filter.dart';
import '../../../services/saved_list_service.dart';
import '../components/property_card.dart';
import '../components/add_to_collection_dialog.dart';

class AllSavedTab extends StatefulWidget {
  final String userId;
  final ContactFilter filter;

  const AllSavedTab({super.key, required this.userId, required this.filter});

  @override
  State<AllSavedTab> createState() => _AllSavedTabState();
}

class _AllSavedTabState extends State<AllSavedTab> {
  final SavedListService _savedListService = SavedListService();
  List<Property> _properties = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  @override
  void didUpdateWidget(AllSavedTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload when filter changes
    if (oldWidget.filter != widget.filter) {
      _loadProperties();
    }
  }

  Future<void> _loadProperties() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final properties = await _savedListService.getFilteredSavedProperties(
        widget.userId,
        widget.filter,
      );
      if (mounted) {
        setState(() {
          _properties = properties;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar propiedades: $e')),
        );
      }
    }
  }

  Future<void> _openCollectionDialog(Property property) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AddToCollectionDialog(propertyId: property.id),
    );

    if (result == true) {
      _loadProperties();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Styles.primaryColor),
      );
    }

    if (_properties.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              _getEmptyMessage(),
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProperties,
      color: Styles.primaryColor,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.62,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _properties.length,
        itemBuilder: (context, index) {
          final property = _properties[index];
          return PropertyCard(
            property: property,
            isFavorite: true, // En esta pestaña siempre son favoritos
            onFavoriteToggle: () => _openCollectionDialog(property),
            onTap: () {
              Modular.to.pushNamed(
                '/property/detail/${property.id}',
                arguments: property,
              );
            },
            showGoldenBorder: false,
          );
        },
      ),
    );
  }

  String _getEmptyMessage() {
    switch (widget.filter) {
      case ContactFilter.all:
        return 'No tienes propiedades guardadas';
      case ContactFilter.contacted:
        return 'No has contactado ninguna propiedad';
      case ContactFilter.notContacted:
        return 'Todas tus propiedades\nhan sido contactadas';
    }
  }
}
