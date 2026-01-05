import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:chaski_comercial/services/ad_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../theme/theme.dart';
// Importamos los nuevos componentes visuales
import '../property/components/category_selector.dart';
import '../property/components/property_carousel.dart';
import '../property/components/property_vertical_list.dart';
import '../property/components/compact_property_card.dart';
import '../property/components/add_to_collection_dialog.dart';

// Asumo que estos archivos existen en tu proyecto
import '../../models/property.dart';
import '../../services/saved_list_service.dart';
import '../property/property_location_search_screen.dart';
import '../../providers/auth_provider.dart';

class InmobiliariaMarketScreen extends StatefulWidget {
  const InmobiliariaMarketScreen({super.key});

  @override
  State<InmobiliariaMarketScreen> createState() =>
      _InmobiliariaMarketScreenState();
}

class _InmobiliariaMarketScreenState extends State<InmobiliariaMarketScreen> {
  String selectedCategory = 'Comprar';
  bool _isLoading = true;
  Position? _currentPosition;

  // Listas separadas por tipo de usuario (sin filtrar)
  List<Property> _allPremiumProperties = [];
  List<Property> _allRealEstateProperties = [];
  List<Property> _allRegularProperties = [];

  // Listas filtradas por categoría
  List<Property> _filteredPremiumProperties = [];
  List<Property> _filteredRealEstateProperties = [];
  List<Property> _filteredRegularProperties = [];

  final Set<String> _savedPropertyIds = {};
  final SavedListService _savedListService = SavedListService();
  final ScrollController _scrollController = ScrollController();

  // Map para almacenar logos de inmobiliarias: propertyId -> companyLogo
  final Map<String, String> _companyLogos = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Scroll listener para futuros eventos
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

      final query = FirebaseFirestore.instance
          .collection('properties')
          .where('is_active', isEqualTo: true);

      // Obtener todos los usuarios (sin filtros complejos para empezar)
      final allUsersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      final premiumUserIds = <String>{};
      final realEstateUserIds = <String>{};

      // Clasificar usuarios por suscripción y rol
      for (var doc in allUsersSnapshot.docs) {
        final userId = doc.id;
        final data = doc.data();
        final role = data['role']?.toString() ?? '';

        // Verificar subscriptionStatus.status (con capital S)
        final subStatus = data['subscriptionStatus'] != null
            ? data['subscriptionStatus']['status']?.toString() ?? ''
            : '';

        print('DEBUG - Usuario: $userId, Rol: $role, SubStatus: $subStatus');

        // Primer IF: Verificar si el usuario tiene subscripción activa
        if (subStatus == 'active') {
          // Segundo IF: Dentro de los usuarios con suscripción activa
          if (role == 'inmobiliaria_empresa') {
            // Si es inmobiliaria empresa, agregarlo a realEstateUserIds
            realEstateUserIds.add(userId);
            print(
              'DEBUG - $userId agregado a REAL ESTATE (inmobiliaria_empresa)',
            );
          } else {
            // Si tiene suscripción activa pero NO es inmobiliaria_empresa, es usuario premium
            premiumUserIds.add(userId);
            print('DEBUG - $userId agregado a PREMIUM (suscripción activa)');
          }
        } else {
          // Usuarios sin subscripción activa permanecen en regular
          print('DEBUG - $userId sin suscripción activa (REGULAR)');
        }
      }

      print('DEBUG - premiumUserIds: $premiumUserIds');
      print('DEBUG - realEstateUserIds: $realEstateUserIds');

      // Crear map de logos de inmobiliarias: userId -> companyLogo
      final userLogos = <String, String>{};
      for (var doc in allUsersSnapshot.docs) {
        final userId = doc.id;
        final data = doc.data();
        final role = data['role']?.toString() ?? '';

        // Solo guardar logos de inmobiliarias
        if (role == 'inmobiliaria_empresa') {
          final logo = data['companyLogo']?.toString() ?? '';
          if (logo.isNotEmpty) {
            userLogos[userId] = logo;
          }
        }
      }

      if (currentUserId.isNotEmpty) {
        final snapshot = await query.get();

        final tempPremium = <Property>[];
        final tempRealEstate = <Property>[];
        final tempRegular = <Property>[];

        for (var doc in snapshot.docs) {
          final data = doc.data();

          // Filtrar propiedades con available = false
          final available = data['available'];
          if (available == false) continue;

          final property = Property.fromFirestore(doc);
          final ownerId = data['owner_id'] as String?;

          if (_currentPosition != null && property.geopoint != null) {
            final gp = property.geopoint!;
            Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              gp.latitude,
              gp.longitude,
            );

            // No filtrar por distancia, mostrar todos
          }

          // Clasificar propiedades por tipo de usuario dueño
          if (ownerId != null) {
            print(
              'DEBUG - Propiedad: ${property.name}, Owner: $ownerId, En Premium: ${premiumUserIds.contains(ownerId)}, En RealEstate: ${realEstateUserIds.contains(ownerId)}',
            );

            // Almacenar el logo si el owner es inmobiliaria
            if (userLogos.containsKey(ownerId)) {
              _companyLogos[property.id] = userLogos[ownerId]!;
            }

            // Primer IF: Verificar si el owner tiene subscriptionstatus.status = "active"
            if (premiumUserIds.contains(ownerId)) {
              // Si tiene subscripción activa, verificar su rol
              // Este es un usuario premium (no es inmobiliaria)
              tempPremium.add(property);
              print('DEBUG - Agregado a PREMIUM');
            } else if (realEstateUserIds.contains(ownerId)) {
              // Si está en realEstateUserIds, es una inmobiliaria
              tempRealEstate.add(property);
              print('DEBUG - Agregado a REAL ESTATE');
            } else {
              // Usuarios sin subscripción activa
              tempRegular.add(property);
              print('DEBUG - Agregado a REGULAR');
            }
          } else {
            tempRegular.add(property);
          }
        }

        // Ordenar cada categoría por fecha (más reciente primero)
        void sortByDate(List<Property> props) {
          props.sort((a, b) {
            final aDate = a.lastPublishedAt ?? a.createdAt ?? DateTime(2000);
            final bDate = b.lastPublishedAt ?? b.createdAt ?? DateTime(2000);
            return bDate.compareTo(aDate);
          });
        }

        sortByDate(tempPremium);
        sortByDate(tempRealEstate);
        sortByDate(tempRegular);

        if (mounted) {
          _allPremiumProperties = tempPremium;
          _allRealEstateProperties = tempRealEstate;
          _allRegularProperties = tempRegular;

          // Aplicar filtros
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

    // Función para filtrar por tipo de transacción
    List<Property> filterByType(List<Property> props) {
      return props.where((p) {
        final type = p.type.toLowerCase();
        return type.contains(dbType) || (dbType == 'sale' && type == 'venta');
      }).toList();
    }

    _filteredPremiumProperties = filterByType(_allPremiumProperties);
    _filteredRealEstateProperties = filterByType(_allRealEstateProperties);
    _filteredRegularProperties = filterByType(_allRegularProperties);

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
                            // Logo con padding reducido
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                Styles.spacingMedium,
                                Styles.spacingSmall,
                                Styles.spacingMedium,
                                Styles.spacingSmall,
                              ),
                              child: Center(
                                child: SvgPicture.asset(
                                  'assets/images/Logo P2.svg',
                                  height: 70,
                                ),
                              ),
                            ),

                            // Botón de búsqueda por ubicación con padding reducido
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
                                    onTap: () async {
                                      await AdService.instance
                                          .showInterstitialThen(() async {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const PropertyLocationSearchScreen(),
                                              ),
                                            );
                                          });
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14.0,
                                        vertical: 12.0,
                                      ),
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
                            SizedBox(height: Styles.spacingSmall),

                            // Botones de Categoría
                            CategorySelector(
                              selectedCategory: selectedCategory,
                              onCategorySelected: _onCategorySelected,
                            ),
                            SizedBox(height: Styles.spacingSmall),
                          ],
                        ),
                      ),
                    ),

                    // CONTENIDO SCROLLEABLE
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        child: Padding(
                          padding: EdgeInsets.only(
                            top: Styles.spacingSmall,
                            bottom: Styles.spacingLarge,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // SECCIÓN: PROPIEDADES PREMIUM (SCROLL HORIZONTAL)
                              if (_filteredPremiumProperties.isNotEmpty)
                                PropertyCarousel(
                                  title: 'Propiedades Premium',
                                  properties: _filteredPremiumProperties,
                                  primaryColor: const Color(0xFFFF6F00),
                                  secondaryColor: const Color(0xFFFFC107),
                                  badgeText: 'PREMIUM',
                                  badgeIcon: Icons.star,
                                  savedPropertyIds: _savedPropertyIds,
                                  onFavoriteToggle: _openCollectionDialog,
                                  onTap: _goToDetail,
                                  companyLogos: _companyLogos,
                                ),

                              // SECCIÓN: PROPIEDADES INMOBILIARIAS (SCROLL HORIZONTAL)
                              if (_filteredRealEstateProperties.isNotEmpty)
                                PropertyCarousel(
                                  title: 'Propiedades de Inmobiliarias',
                                  properties: _filteredRealEstateProperties,
                                  primaryColor: const Color(0xFF1976D2),
                                  secondaryColor: const Color(0xFF42A5F5),
                                  badgeText: 'INMOBILIARIA',
                                  badgeIcon: Icons.business,
                                  savedPropertyIds: _savedPropertyIds,
                                  onFavoriteToggle: _openCollectionDialog,
                                  onTap: _goToDetail,
                                  companyLogos: _companyLogos,
                                ),

                              // SECCIÓN: PROPIEDADES REGULARES (SCROLL VERTICAL INFINITO)
                              if (_filteredRegularProperties.isNotEmpty)
                                PropertyVerticalList(
                                  title: 'Todas las Propiedades',
                                  properties: _filteredRegularProperties,
                                  titleColor: const Color(0xFF2C3E50),
                                  savedPropertyIds: _savedPropertyIds,
                                  onFavoriteToggle: _openCollectionDialog,
                                  onTap: _goToDetail,
                                  hasMore: false,
                                  isLoading: false,
                                  companyLogos: _companyLogos,
                                ),

                              if (_filteredPremiumProperties.isEmpty &&
                                  _filteredRealEstateProperties.isEmpty &&
                                  _filteredRegularProperties.isEmpty)
                                Padding(
                                  padding: EdgeInsets.all(Styles.spacingMedium),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.apartment,
                                          size: 64,
                                          color: Colors.grey[400],
                                        ),
                                        SizedBox(height: Styles.spacingMedium),
                                        Text(
                                          'No se encontraron propiedades',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'en la categoría seleccionada',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[500],
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
                  ],
                ),
              ],
            ),
    );
  }
}
