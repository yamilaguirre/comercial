import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/theme.dart';
// Importamos los nuevos componentes visuales
import 'components/category_selector.dart';
import 'components/property_card_list_item.dart';
import 'components/compact_property_card.dart';
import 'components/add_to_collection_dialog.dart';

// Asumo que estos archivos existen en tu proyecto
import '../../models/property.dart';
import '../../services/saved_list_service.dart';
import 'property_location_search_screen.dart';
import '../../providers/auth_provider.dart';

class PropertyListScreen extends StatefulWidget {
  const PropertyListScreen({super.key});

  @override
  State<PropertyListScreen> createState() => _PropertyListScreenState();
}

class _PropertyListScreenState extends State<PropertyListScreen> {
  String selectedCategory = 'Comprar';
  bool _isLoading = true;
  Position? _currentPosition;
  List<Property> _allProperties = [];
  List<Property> _filteredProperties = [];
  final Set<String> _savedPropertyIds = {};
  final SavedListService _savedListService = SavedListService();

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final locationFuture = _getCurrentLocation();
    final propertiesFuture = _fetchProperties();
    final savedFuture = _checkSavedProperties();

    await Future.wait([locationFuture, propertiesFuture, savedFuture]);
  }

  Future<void> _checkSavedProperties() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid ?? '';
    if (userId.isEmpty) return;

    final savedProperties = await _savedListService.getAllSavedProperties(
      userId,
    );
    if (mounted) {
      setState(() {
        _savedPropertyIds.clear();
        _savedPropertyIds.addAll(savedProperties.map((p) => p.id));
      });
    }
  }

  Future<void> _openCollectionDialog(Property property) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid ?? '';

    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes iniciar sesión para guardar propiedades'),
        ),
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AddToCollectionDialog(propertyId: property.id),
    );

    if (result == true) {
      // Refresh saved status
      await _checkSavedProperties();
    }
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
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUserId = authService.currentUser?.uid ?? '';
      final isPremium = authService.isPremium;

      final searchRadiusMeters = isPremium ? 10000.0 : 10000.0;

      final query = FirebaseFirestore.instance
          .collection('properties')
          .where('is_active', isEqualTo: true);

      if (currentUserId.isNotEmpty) {
        final snapshot = await query.get();

        final tempProperties = <Map<String, dynamic>>[];

        for (var doc in snapshot.docs) {
          final data = doc.data();
          if (data['owner_id'] == currentUserId) continue;
          
          // Filtrar propiedades con available = false
          final available = data['available'];
          if (available == false) continue;

          final property = Property.fromFirestore(doc);
          double distance = double.infinity;

          if (_currentPosition != null && property.geopoint != null) {
            final gp = property.geopoint!;
            distance = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              gp.latitude,
              gp.longitude,
            );

            if (distance > searchRadiusMeters) continue;
          }

          tempProperties.add({'obj': property, 'distance': distance});
        }

        tempProperties.sort(
          (a, b) =>
              (a['distance'] as double).compareTo(b['distance'] as double),
        );

        if (mounted) {
          _allProperties = tempProperties
              .map((e) => e['obj'] as Property)
              .toList();
          _filterProperties();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando propiedades: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterProperties() {
    final dbType = selectedCategory == 'Comprar'
        ? 'sale'
        : selectedCategory == 'Alquiler'
        ? 'rent'
        : 'anticretico';

    _filteredProperties = _allProperties.where((p) {
      final type = p.type.toLowerCase();
      return type.contains(dbType) || (dbType == 'sale' && type == 'venta');
    }).toList();

    // Ordenar por fecha de publicación (más reciente primero)
    _filteredProperties.sort((a, b) {
      final aDate = a.lastPublishedAt ?? a.createdAt ?? DateTime(2000);
      final bDate = b.lastPublishedAt ?? b.createdAt ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });

    if (mounted) setState(() {});
  }

  // Método callback para actualizar la categoría desde CategorySelector
  void _onCategorySelected(String category) {
    setState(() {
      selectedCategory = category;
      _filterProperties();
    });
  }

  // Método para navegar al detalle (Migrado a Modular)
  void _goToDetail(Property property) {
    Modular.to.pushNamed(
      '/property/detail/${property.id}',
      arguments: property, // Pasa el objeto para carga rápida
    );
  }

  void _changeModule() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    if (user == null) {
      Modular.to.navigate('/login');
      return;
    }

    try {
      await authService.updateUserRole('trabajo');
      Modular.to.navigate('/worker/home-worker');
    } catch (e) {
      debugPrint('Error al cambiar de módulo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Styles.primaryColor),
            )
          : Stack(
              children: [
                Column(
              children: [
                // HEADER FIJO
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Logo
                        Padding(
                          padding: EdgeInsets.all(Styles.spacingMedium),
                          child: Image.asset(
                            'assets/images/logoColor.png',
                            height: 50,
                            fit: BoxFit.contain,
                          ),
                        ),

                        // Botón de búsqueda por ubicación
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: Styles.spacingMedium,
                          ),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Styles.primaryColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const PropertyLocationSearchScreen(),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: const [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Buscar por ubicación',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Encuentra propiedades cerca de ti',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Icon(
                                        Icons.map,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: Styles.spacingMedium),

                        // Botones de Categoría
                        CategorySelector(
                          selectedCategory: selectedCategory,
                          onCategorySelected: _onCategorySelected,
                        ),
                        SizedBox(height: Styles.spacingMedium),
                      ],
                    ),
                  ),
                ),

                // CONTENIDO SCROLLEABLE
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Título: Recomendados cerca de ti
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: Styles.spacingMedium,
                          ),
                          child: Consumer<AuthService>(
                            builder: (context, authService, _) {
                              final isPremium = authService.isPremium;
                              final radiusText = isPremium ? '10 km' : '10 km';
                              return Text(
                                'Recomendados cerca de ti ($radiusText aprox)',
                                style: TextStyles.title.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                        ),
                        SizedBox(height: Styles.spacingMedium),

                        // Lista de Propiedades Filtradas (Grid)
                        if (_filteredProperties.isEmpty)
                          Padding(
                            padding: EdgeInsets.all(Styles.spacingMedium),
                            child: const Text(
                              'No se encontraron propiedades cercanas en esta categoría.',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
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
                                    childAspectRatio: 0.85,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                  ),
                              itemCount: _filteredProperties.length,
                              itemBuilder: (context, index) {
                                return CompactPropertyCard(
                                  property: _filteredProperties[index],
                                  isFavorite: _savedPropertyIds.contains(
                                    _filteredProperties[index].id,
                                  ),
                                  onFavoriteToggle: () => _openCollectionDialog(
                                    _filteredProperties[index],
                                  ),
                                  onTap: () =>
                                      _goToDetail(_filteredProperties[index]),
                                );
                              },
                            ),
                          ),
                        SizedBox(height: Styles.spacingLarge),
                      ],
                    ),
                  ),
                ),
              ],
            ),
                Positioned(
                  bottom: 24,
                  right: 16,
                  child: GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          title: Row(
                            children: const [
                              Icon(Icons.work, color: Styles.primaryColor, size: 28),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Cambiar a Trabajadores',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          content: const Text(
                            '¿Deseas cambiar al módulo de Trabajadores para buscar servicios?',
                            style: TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancelar'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _changeModule();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Styles.primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                              child: const Text('Cambiar'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Styles.primaryColor,
                            Color(0xFF1565C0),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Styles.primaryColor.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.work,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Trabajadores',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
