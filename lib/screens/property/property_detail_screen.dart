import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// Importaciones de Mapa (Asumo que _buildMapSection todavía está en esta pantalla)
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../models/property.dart';
import '../../theme/theme.dart';
import '../../core/utils/amenity_helper.dart';
import '../../core/utils/property_constants.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../services/saved_list_service.dart';
import '../../providers/mobiliaria_provider.dart';

import 'components/detail_feature_item.dart';
import 'components/detail_owner_contact_card.dart';
import 'components/add_to_collection_dialog.dart';
import 'components/compact_property_card.dart';

// --- CONSTANTES DE MAPA (RESTAURADAS) ---
const String _mapboxAccessToken =
    'pk.eyJ1IjoibXVqZXJlc2Fsdm9sYW50ZSIsImEiOiJjbWFoZTR1ZzEwYXdvMmtxMHg5ZXZneXgyIn0.9aNpyQyi5wP1qKi0SjiR5Q';
const String _mapboxStyleId =
    'mapbox/streets-v12'; // Estilos disponibles: streets-v12, outdoors-v12, light-v11, dark-v11, satellite-v9

class PropertyDetailScreen extends StatefulWidget {
  final String propertyId;
  final Property? propertyData;

  const PropertyDetailScreen({
    super.key,
    required this.propertyId,
    this.propertyData,
  });

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen>
    implements
        DetailOwnerContactCardCallbacks // Implementamos la interfaz
        {
  Property? _property;
  Map<String, dynamic>? _ownerData;
  bool _isLoading = true;
  bool _isFavorite = false;
  int _currentImageIndex = 0;
  final PageController _carouselController = PageController();
  final SavedListService _savedListService = SavedListService();
  List<Property> _similarProperties = [];
  final Set<String> _savedPropertyIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkIfSaved();
    _loadSimilarProperties();
  }

  @override
  void dispose() {
    _carouselController.dispose();
    super.dispose();
  }

  // Verificar si la propiedad está guardada
  Future<void> _checkIfSaved() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid ?? '';

    if (userId.isEmpty || _property == null) return;

    final isSaved = await _savedListService.isPropertySaved(
      userId,
      widget.propertyId,
    );
    
    final savedProperties = await _savedListService.getAllSavedProperties(userId);
    
    if (mounted) {
      setState(() {
        _isFavorite = isSaved;
        _savedPropertyIds.clear();
        _savedPropertyIds.addAll(savedProperties.map((p) => p.id));
      });
    }
  }

  // Cargar propiedades similares
  Future<void> _loadSimilarProperties() async {
    if (_property == null) return;

    try {
      final query = FirebaseFirestore.instance
          .collection('properties')
          .where('is_active', isEqualTo: true)
          .where('transaction_type', isEqualTo: _property!.type)
          .where('property_type', isEqualTo: _property!.propertyTypeRaw)
          .limit(10);

      final snapshot = await query.get();
      final properties = snapshot.docs
          .where((doc) => doc.id != widget.propertyId && (doc.data()['available'] ?? true))
          .map((doc) => Property.fromFirestore(doc))
          .toList();

      properties.sort((a, b) {
        final aDate = a.lastPublishedAt ?? a.createdAt ?? DateTime(2000);
        final bDate = b.lastPublishedAt ?? b.createdAt ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });

      if (mounted) {
        setState(() {
          _similarProperties = properties.take(6).toList();
        });
      }
    } catch (e) {
      debugPrint('Error cargando propiedades similares: $e');
    }
  }

  // Guardar/quitar de favoritos
  Future<void> _toggleFavorite() async {
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

    if (_isFavorite) {
      // Mostrar opciones para quitar de colecciones
      final collections = await _savedListService.getCollectionsWithProperty(
        userId,
        widget.propertyId,
      );

      if (collections.isEmpty) return;

      // Quitar de todas las colecciones
      for (final collection in collections) {
        await _savedListService.removePropertyFromCollection(
          collection.id,
          widget.propertyId,
        );
      }

      if (mounted) {
        setState(() => _isFavorite = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Quitado de favoritos')));
      }
    } else {
      // Mostrar diálogo para agregar a colecciones
      final result = await showDialog<bool>(
        context: context,
        builder: (context) =>
            AddToCollectionDialog(propertyId: widget.propertyId),
      );

      if (result == true) {
        _checkIfSaved();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Agregado a favoritos')));
        }
      }
    }
  }

  // Abrir diálogo de colección para propiedades similares
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
      await _checkIfSaved();
    }
  }

  // Lógica de carga de datos
  Future<void> _loadData() async {
    try {
      if (widget.propertyData != null) {
        _property = widget.propertyData;
      } else {
        final doc = await FirebaseFirestore.instance
            .collection('properties')
            .doc(widget.propertyId)
            .get();
        if (doc.exists) {
          _property = Property.fromFirestore(doc);
        }
      }

      if (_property != null && _property!.ownerId.isNotEmpty) {
        final ownerDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_property!.ownerId)
            .get();

        if (ownerDoc.exists) {
          _ownerData = ownerDoc.data();
        }
      }
    } catch (e) {
      debugPrint("Error cargando detalle: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);

      // Incrementar vistas si la carga fue exitosa
      if (_property != null) {
        // Usamos Modular.get o Provider.of, pero como estamos en un método async,
        // es mejor asegurar que el contexto siga montado o usar Modular.get si es seguro.
        // Aquí usamos Modular.get<MobiliariaProvider>() ya que es un singleton lazy.
        Modular.get<MobiliariaProvider>().incrementPropertyView(
          widget.propertyId,
        );
      }
    }
  }

  // Implementación del método de contacto desde la interfaz
  @override
  Future<void> contactOwner(String type) async {
    if (_ownerData == null) return;

    final phone = _ownerData?['phoneNumber'] as String? ?? '';
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El propietario no tiene teléfono registrado'),
        ),
      );
      return;
    }

    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    final finalPhone = (cleanPhone.length == 8 && !cleanPhone.startsWith('591'))
        ? '591$cleanPhone'
        : cleanPhone;

    Uri uri;
    if (type == 'whatsapp') {
      final message = Uri.encodeComponent(
        'Hola ${_ownerData?['displayName'] ?? ''}, vi tu propiedad "${_property?.name}" en Comercial y estoy interesado.',
      );
      uri = Uri.parse("https://wa.me/$finalPhone?text=$message");
    } else {
      uri = Uri.parse("tel:$finalPhone");
    }

    // Incrementar consultas si es WhatsApp (teléfono también podría contar si se desea)
    if (type == 'whatsapp') {
      Modular.get<MobiliariaProvider>().incrementPropertyInquiry(
        widget.propertyId,
      );
    }

    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'No se pudo lanzar $uri';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo abrir ${type == 'whatsapp' ? 'WhatsApp' : 'el teléfono'}',
            ),
          ),
        );
      }
    }
  }

  // Implementación del chat interno desde la interfaz
  @override
  Future<void> startInternalChat() async {
    if (_property == null || _ownerData == null) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUserId = authService.currentUser?.uid ?? '';

    if (currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para chatear')),
      );
      return;
    }

    // No permitir chat con uno mismo
    if (currentUserId == _property!.ownerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No puedes chatear contigo mismo')),
      );
      return;
    }

    try {
      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final chatService = ChatService();

      // Buscar chat existente
      String? chatId = await chatService.findExistingChat(_property!.id, [
        currentUserId,
        _property!.ownerId,
      ]);

      // Si no existe, crear uno nuevo
      if (chatId == null) {
        final initialMessage =
            'Hola, estoy interesado en tu propiedad "${_property!.name}"';
        chatId = await chatService.createChat(
          propertyId: _property!.id,
          userIds: [currentUserId, _property!.ownerId],
          initialMessage: initialMessage,
          senderId: currentUserId,
        );
      }

      // Cerrar indicador de carga
      if (mounted) Navigator.of(context).pop();

      if (chatId != null) {
        // Navegar al chat
        Modular.to.pushNamed(
          '/property/chat-detail',
          arguments: {
            'chatId': chatId,
            'otherUserId': _property!.ownerId,
            'otherUserName': _ownerData?['displayName'] ?? 'Usuario',
            'otherUserPhoto': _ownerData?['photoURL'],
            'propertyId': _property!.id,
          },
        );

        // Incrementar consultas al iniciar chat exitosamente
        Modular.get<MobiliariaProvider>().incrementPropertyInquiry(
          widget.propertyId,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al crear el chat')),
          );
        }
      }
    } catch (e) {
      // Cerrar indicador de carga si está abierto
      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _openFullScreenGallery(List<String> images, int initialIndex) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            _FullScreenGalleryDialog(
              images: images,
              initialIndex: initialIndex,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
        opaque: false,
      ),
    );
  }

  // --- WIDGETS AUXILIARES (DE VUELTA A LA PANTALLA PRINCIPAL O REFERENCIANDO COMPONENTES) ---

  // Sección principal de detalles (no deslizable)
  Widget _buildPrimaryDetailsHeader() {
    if (_property == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Styles.spacingLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _property!.price,
                style: TextStyles.title.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Styles.primaryColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Styles.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  PropertyConstants.getTransactionTitle(
                    _property!.type,
                  ).toUpperCase(),
                  style: TextStyle(
                    color: Styles.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _property!.name,
            style: TextStyles.subtitle.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: Colors.grey,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _property!.location,
                  style: TextStyles.body.copyWith(color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              DetailFeatureItem(
                icon: Icons.bed_outlined,
                value: '${_property!.bedrooms}',
                label: 'Habit.',
              ),
              DetailFeatureItem(
                icon: Icons.bathtub_outlined,
                value: '${_property!.bathrooms}',
                label: 'Baños',
              ),
              DetailFeatureItem(
                icon: Icons.square_foot,
                value: '${_property!.area.toStringAsFixed(0)} m²',
                label: 'Área',
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
        ],
      ),
    );
  }

  // Contenido adicional (DESLIZABLE)
  Widget _buildScrollableContent() {
    if (_property == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Styles.spacingLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Descripción',
            style: TextStyles.subtitle.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            _property!.description,
            style: TextStyles.body.copyWith(
              color: Colors.grey[800],
              height: 1.5,
            ),
            maxLines: 20,
            overflow: TextOverflow.fade,
          ),
          const SizedBox(height: 24),
          if (_property!.amenities.isNotEmpty) ...[
            Text(
              'Comodidades',
              style: TextStyles.subtitle.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _property!.amenities.map((key) {
                final label = PropertyConstants.amenityLabels[key] ?? key;
                return Chip(
                  avatar: Icon(
                    AmenityHelper.getIcon(key),
                    size: 16,
                    color: Styles.primaryColor,
                  ),
                  label: Text(label, style: const TextStyle(fontSize: 12)),
                  backgroundColor: Styles.primaryColor.withOpacity(0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: Styles.primaryColor.withOpacity(0.2),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],
          if (_property!.geopoint != null) ...[
            Text(
              'Ubicación',
              style: TextStyles.subtitle.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildMapSection(), // Se mantiene aquí
            const SizedBox(height: 24),
          ],
          if (_similarProperties.isNotEmpty) ...[
            const Divider(),
            const SizedBox(height: 24),
            Text(
              'Te podría interesar',
              style: TextStyles.subtitle.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _similarProperties.length,
              itemBuilder: (context, index) {
                return CompactPropertyCard(
                  property: _similarProperties[index],
                  isFavorite: _savedPropertyIds.contains(_similarProperties[index].id),
                  onFavoriteToggle: () => _openCollectionDialog(_similarProperties[index]),
                  onTap: () => Modular.to.pushNamed(
                    '/property/detail/${_similarProperties[index].id}',
                    arguments: _similarProperties[index],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
          const SizedBox(height: 50), // Espacio extra al final del scroll
        ],
      ),
    );
  }

  // Carrusel (Se mantiene la lógica en la pantalla)
  Widget _buildCarouselSection(List<Map<String, dynamic>> mediaItems) {
    if (mediaItems.isEmpty) {
      return Container(
        height: 350,
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
        ),
      );
    }

    return SizedBox(
      height: 350,
      child: Stack(
        children: [
          PageView.builder(
            controller: _carouselController,
            itemCount: mediaItems.length,
            physics: const ClampingScrollPhysics(),
            onPageChanged: (index) {
              if (mounted) {
                setState(() => _currentImageIndex = index);
              }
            },
            itemBuilder: (context, index) {
              final item = mediaItems[index];
              if (item['type'] == 'video') {
                return _VideoPlayerWidget(videoUrl: item['url']);
              }
              return GestureDetector(
                onTap: () {
                  final images = mediaItems
                      .where((m) => m['type'] == 'image')
                      .map((m) => m['url'] as String)
                      .toList();
                  final imageIndex = images.indexOf(item['url']);
                  _openFullScreenGallery(images, imageIndex);
                },
                child: Image.network(
                  item['url'],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(color: Colors.grey[200]);
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                ),
              );
            },
          ),
          // Flechas de navegacion
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            child: IconButton(
              icon: const Icon(
                Icons.chevron_left,
                color: Colors.white,
                size: 30,
              ),
              onPressed: () {
                if (_currentImageIndex > 0) {
                  _carouselController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.ease,
                  );
                }
              },
            ),
          ),
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            child: IconButton(
              icon: const Icon(
                Icons.chevron_right,
                color: Colors.white,
                size: 30,
              ),
              onPressed: () {
                if (_currentImageIndex < mediaItems.length - 1) {
                  _carouselController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.ease,
                  );
                }
              },
            ),
          ),
          // Controles de la barra de estado y favoritos/volver (USANDO MODULAR)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 4),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                      onPressed: () => Modular.to.pop(),
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 4),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: _isFavorite ? Colors.red : Colors.black,
                      ),
                      onPressed: _toggleFavorite,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Indicadores de página
          if (mediaItems.length > 1)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: mediaItems.asMap().entries.map((entry) {
                  final isActive = _currentImageIndex == entry.key;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: isActive ? 12.0 : 8.0,
                    height: 8.0,
                    margin: const EdgeInsets.symmetric(horizontal: 3.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: Colors.white.withOpacity(isActive ? 1.0 : 0.5),
                    ),
                  );
                }).toList(),
              ),
            ),

        ],
      ),
    );
  }

  // Mapa (Se mantiene en esta pantalla ya que requiere dependencias específicas)
  Widget _buildMapSection() {
    if (_property!.geopoint == null) return const SizedBox.shrink();
    final lat = _property!.geopoint!.latitude;
    final lng = _property!.geopoint!.longitude;

    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(lat, lng),
            initialZoom: 15.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
            ),
          ),
          children: [
            // --- MAPBOX TILE LAYER ---
            TileLayer(
              urlTemplate:
                  'https://api.mapbox.com/styles/v1/$_mapboxStyleId/tiles/256/{z}/{x}/{y}@2x?access_token=$_mapboxAccessToken',
              userAgentPackageName: 'com.mobiliaria.app',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: LatLng(lat, lng),
                  width: 40,
                  height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Styles.primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.home,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET PRINCIPAL BUILD ---

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Styles.primaryColor),
        ),
      );
    }

    if (_property == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Propiedad no encontrada')),
      );
    }

    // Solo imágenes para el carrusel (sin videos)
    final List<String> imagesToShow = _property!.imageUrls.isNotEmpty
        ? _property!.imageUrls.where((url) => url.isNotEmpty).toList()
        : (_property!.imageUrl.isNotEmpty ? [_property!.imageUrl] : []);

    // Combinar imágenes y videos para el carrusel
    final List<Map<String, dynamic>> mediaItems = [
      ...imagesToShow.map((url) => {'type': 'image', 'url': url}),
      ..._property!.videoUrls.map((url) => {'type': 'video', 'url': url}),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Carrusel (350 de altura)
            _buildCarouselSection(mediaItems),

            // 2. Card de Contacto del Dueño
            DetailOwnerContactCard(
              ownerData: _ownerData,
              propertyName: _property!.name,
              callbacks: this,
            ),

            // 3. Contenido Principal
            _buildPrimaryDetailsHeader(),
            _buildScrollableContent(),
          ],
        ),
      ),
    );
  }
}

// Mantenemos este diálogo aquí
class _FullScreenGalleryDialog extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  const _FullScreenGalleryDialog({
    required this.images,
    required this.initialIndex,
  });
  @override
  State<_FullScreenGalleryDialog> createState() =>
      _FullScreenGalleryDialogState();
}

class _FullScreenGalleryDialogState extends State<_FullScreenGalleryDialog> {
  late PageController _pageController;
  late int _currentIndex;
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            physics: const ClampingScrollPhysics(),
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.network(
                    widget.images[index],
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Positioned(
              top: 20,
              left: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Widget para reproducir videos
class _VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  const _VideoPlayerWidget({required this.videoUrl});

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) setState(() => _isInitialized = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _controller.value.isPlaying ? _controller.pause() : _controller.play();
        });
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller.value.size.width,
              height: _controller.value.size.height,
              child: VideoPlayer(_controller),
            ),
          ),
          if (!_controller.value.isPlaying)
            Center(
              child: Icon(
                Icons.play_circle_outline,
                size: 64,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
        ],
      ),
    );
  }
}
