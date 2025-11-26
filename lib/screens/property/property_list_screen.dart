import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/theme.dart';
// Importamos los nuevos componentes visuales
import 'components/category_selector.dart';
import 'components/property_card_list_item.dart';

// Asumo que estos archivos existen en tu proyecto
import '../../models/property.dart';
// import '../../core/utils/amenity_helper.dart'; // Ya no es necesario aquí
// import '../../core/utils/property_constants.dart'; // Ya no es necesario aquí

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
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Servicios de ubicación deshabilitados.'),
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Permisos de ubicación denegados.')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permisos de ubicación denegados permanentemente.'),
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error obteniendo ubicación: $e')),
        );
      }
    }
  }

  Future<void> _fetchProperties() async {
    setState(() => _isLoading = true);
    try {
      // Usar QuerySnapshot para obtener la colección
      final snapshot = await FirebaseFirestore.instance
          .collection('properties')
          .where('is_active', isEqualTo: true)
          .get();

      List<Map<String, dynamic>> tempProperties = [];

      for (var doc in snapshot.docs) {
        // Asegúrate de que Property.fromFirestore puede manejar el DocumentSnapshot
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

        // Filtro de distancia de 10 km (10000 metros)
        if (distance > 10000) continue;

        tempProperties.add({'obj': property, 'distance': distance});
      }

      // Ordenar por distancia (los más cercanos primero)
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando propiedades: $e')),
        );
        setState(() => _isLoading = false);
      }
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

      // Filtro por tipo
      _filteredProperties = _allProperties.where((p) {
        // Tu lógica de filtro original
        return p.type.toLowerCase().contains(dbType) ||
            (dbType == 'sale' && p.type.toLowerCase() == 'venta');
      }).toList();
    });
  }

  // Método callback para actualizar la categoría desde CategorySelector
  void _onCategorySelected(String category) {
    setState(() {
      selectedCategory = category;
      _filterProperties();
    });
  }

  // Método callback para cambiar la vista desde CategorySelector
  void _onToggleView(bool detailed) {
    setState(() {
      isDetailedView = detailed;
    });
  }

  // Método para navegar al detalle (Migrado a Modular)
  void _goToDetail(Property property) {
    // Usamos Modular.to.pushNamed o Modular.to.navigate con la ruta absoluta
    // y enviamos el objeto 'Property' como argumento (data).
    // Tu PropertyModule espera '/detail/:id'
    Modular.to.pushNamed(
      '/property/detail/${property.id}',
      arguments: property, // Pasa el objeto para carga rápida
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // Quitamos el SafeArea principal ya que el Layout ya lo maneja
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Styles.primaryColor),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Espacio superior (corregido en el paso anterior)
                  const SizedBox(height: 16),

                  // Logo
                  Padding(
                    padding: EdgeInsets.all(Styles.spacingMedium),
                    child: Image.asset(
                      'assets/images/logoColor.png',
                      height: 50,
                      fit: BoxFit.contain,
                    ),
                  ),

                  // Botones de Categoría (USANDO EL NUEVO COMPONENTE)
                  CategorySelector(
                    selectedCategory: selectedCategory,
                    onCategorySelected: _onCategorySelected,
                    isDetailedView: isDetailedView,
                    onToggleView: _onToggleView,
                  ),
                  SizedBox(height: Styles.spacingSmall),

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
                        prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
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

                  // Título: Recomendados cerca de ti
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

                  // Lista de Propiedades Filtradas (Horizontal o Grid)
                  if (_filteredProperties.isEmpty)
                    Padding(
                      padding: EdgeInsets.all(Styles.spacingMedium),
                      child: const Text(
                        'No se encontraron propiedades cercanas en esta categoría.',
                      ),
                    )
                  else if (isDetailedView)
                    // Vista Detallada Horizontal
                    SizedBox(
                      height: 420,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(
                          horizontal: Styles.spacingMedium,
                        ),
                        itemCount: _filteredProperties.length,
                        itemBuilder: (context, index) {
                          return PropertyCardListItem(
                            property: _filteredProperties[index],
                            style: PropertyCardStyle.detailed,
                            onTap: () => _goToDetail(_filteredProperties[index]),
                          );
                        },
                      ),
                    )
                  else
                    // Vista de Cuadrícula Simple
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
                          return PropertyCardListItem(
                            property: _filteredProperties[index],
                            style: PropertyCardStyle.grid,
                            onTap: () => _goToDetail(_filteredProperties[index]),
                          );
                        },
                      ),
                    ),
                  SizedBox(height: Styles.spacingLarge),

                  // Título: Últimas publicadas
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
                          onPressed: () {
                            // TODO: Implementar navegación a 'Ver todo' (ej: /property/all)
                          },
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

                  // Lista de Últimas Propiedades (Horizontal)
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
                        return PropertyCardListItem(
                          property: _allProperties[index],
                          style: PropertyCardStyle.small,
                          onTap: () => _goToDetail(_allProperties[index]),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: Styles.spacingLarge),
                ],
              ),
            ),
    );
  }
}