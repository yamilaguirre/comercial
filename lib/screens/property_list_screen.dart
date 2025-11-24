import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart'; // Necesario para navegación
import '../theme/theme.dart';
import '../models/property.dart';
import '../core/utils/amenity_helper.dart';
import '../core/utils/property_constants.dart';

class PropertyListScreen extends StatefulWidget {
  const PropertyListScreen({super.key});

  @override
  State<PropertyListScreen> createState() => _PropertyListScreenState();
}

class _PropertyListScreenState extends State<PropertyListScreen> {
  String selectedCategory = 'Comprar';
  bool isDetailedView = true;
  bool _isLoading = true;
  Position? _currentPosition;
  List<Property> _allProperties = [];
  List<Property> _filteredProperties = [];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _getCurrentLocation();
    await _fetchProperties();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    } catch (e) {
      // Manejo silencioso de errores de GPS
    }
  }

  Future<void> _fetchProperties() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('properties')
          .where('is_active', isEqualTo: true)
          .get();

      List<Map<String, dynamic>> tempProperties = [];

      for (var doc in snapshot.docs) {
        final property = Property.fromFirestore(doc);
        double distance = double.infinity;

        if (_currentPosition != null && property.geopoint != null) {
          GeoPoint gp = property.geopoint!;
          distance = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            gp.latitude,
            gp.longitude,
          );
        }

        // Filtro de distancia de 10 km
        if (distance > 10000) continue;

        tempProperties.add({'obj': property, 'distance': distance});
      }

      tempProperties.sort(
        (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
      );

      if (mounted) {
        setState(() {
          _allProperties = tempProperties
              .map((e) => e['obj'] as Property)
              .toList();
          _filterProperties();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterProperties() {
    setState(() {
      String dbType = '';
      switch (selectedCategory) {
        case 'Comprar':
          dbType = 'sale';
          break;
        case 'Alquiler':
          dbType = 'rent';
          break;
        case 'Anticrético':
          dbType = 'anticretico';
          break;
      }

      _filteredProperties = _allProperties.where((p) {
        return p.type.toLowerCase().contains(dbType) ||
            (dbType == 'sale' && p.type == 'venta');
      }).toList();
    });
  }

  void _onCategorySelected(String category) {
    setState(() {
      selectedCategory = category;
      _filterProperties();
    });
  }

  // Método para navegar al detalle
  void _goToDetail(Property property) {
    // Pasamos el objeto 'extra' para carga instantánea
    context.push('/property-detail/${property.id}', extra: property);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Styles.primaryColor),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(Styles.spacingMedium),
                      child: Image.asset(
                        'assets/images/logoColor.png',
                        height: 50,
                        fit: BoxFit.contain,
                      ),
                    ),

                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: Styles.spacingMedium,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildCategoryButton('Comprar'),
                                ),
                                SizedBox(width: Styles.spacingSmall),
                                Expanded(
                                  child: _buildCategoryButton('Alquiler'),
                                ),
                                SizedBox(width: Styles.spacingSmall),
                                Expanded(
                                  child: _buildCategoryButton('Anticrético'),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: Styles.spacingSmall),
                          GestureDetector(
                            onTap: () => setState(
                              () => isDetailedView = !isDetailedView,
                            ),
                            child: Container(
                              padding: EdgeInsets.all(Styles.spacingSmall),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isDetailedView
                                    ? Icons.grid_view
                                    : Icons.view_agenda,
                                color: Styles.primaryColor,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: Styles.spacingMedium),

                    // Search
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: Styles.spacingMedium,
                      ),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Dirección: avenida, calle y número',
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.grey[400],
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF5F5F5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            vertical: Styles.spacingSmall,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: Styles.spacingLarge),

                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: Styles.spacingMedium,
                      ),
                      child: Text(
                        'Recomendados cerca de ti (10 km aprox)',
                        style: TextStyles.title.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: Styles.spacingMedium),

                    if (_filteredProperties.isEmpty)
                      Padding(
                        padding: EdgeInsets.all(Styles.spacingMedium),
                        child: const Text(
                          'No se encontraron propiedades cercanas en esta categoría.',
                        ),
                      )
                    else if (isDetailedView)
                      SizedBox(
                        height: 420,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.symmetric(
                            horizontal: Styles.spacingMedium,
                          ),
                          itemCount: _filteredProperties.length,
                          itemBuilder: (context, index) {
                            return _buildPropertyCard(
                              _filteredProperties[index],
                            );
                          },
                        ),
                      )
                    else
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: Styles.spacingMedium,
                        ),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.65,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          itemCount: _filteredProperties.length,
                          itemBuilder: (context, index) {
                            return _buildSimplePropertyCard(
                              _filteredProperties[index],
                            );
                          },
                        ),
                      ),
                    SizedBox(height: Styles.spacingLarge),

                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: Styles.spacingMedium,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.flash_on,
                                color: Styles.primaryColor,
                                size: 24,
                              ),
                              SizedBox(width: Styles.spacingXSmall),
                              Text(
                                'Últimas publicadas',
                                style: TextStyles.title.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () {},
                            child: Text(
                              'Ver todo',
                              style: TextStyle(
                                color: Styles.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: Styles.spacingMedium),

                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(
                          horizontal: Styles.spacingMedium,
                        ),
                        itemCount: _allProperties.length > 5
                            ? 5
                            : _allProperties.length,
                        itemBuilder: (context, index) {
                          return _buildSmallPropertyCard(_allProperties[index]);
                        },
                      ),
                    ),
                    SizedBox(height: Styles.spacingLarge),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildCategoryButton(String title) {
    final isSelected = selectedCategory == title;
    return GestureDetector(
      onTap: () => _onCategorySelected(title),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: Styles.spacingSmall),
        decoration: BoxDecoration(
          color: isSelected ? Styles.primaryColor : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyles.body.copyWith(
            color: isSelected ? Colors.white : Styles.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildPropertyCard(Property property) {
    return GestureDetector(
      onTap: () => _goToDetail(property), // <--- Conectado
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

            Padding(
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
                ],
              ),
            ),
            const Spacer(),
            Padding(
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallPropertyCard(Property property) {
    return GestureDetector(
      onTap: () => _goToDetail(property), // <--- Conectado
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

  Widget _buildSimplePropertyCard(Property property) {
    return GestureDetector(
      onTap: () => _goToDetail(property), // <--- Conectado
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
}
