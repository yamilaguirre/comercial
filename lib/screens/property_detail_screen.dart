import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/property.dart';
import '../theme/theme.dart';
import '../core/utils/amenity_helper.dart';
import '../core/utils/property_constants.dart';

// --- CONSTANTES DE MAPA (TOKEN REAL) ---
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

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  Property? _property;
  Map<String, dynamic>? _ownerData;
  bool _isLoading = true;
  bool _isFavorite = false;
  int _currentImageIndex = 0;
  final PageController _carouselController = PageController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _carouselController.dispose();
    super.dispose();
  }

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
    }
  }

  Future<void> _contactOwner(String type) async {
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
        'Hola ${_ownerData?['displayName'] ?? ''}, vi tu propiedad "${_property?.name}" en MobiliariaAPP y estoy interesado.',
      );
      uri = Uri.parse("https://wa.me/$finalPhone?text=$message");
    } else {
      uri = Uri.parse("tel:$finalPhone");
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

  void _startInternalChat() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chat interno próximamente...')),
    );
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

    final List<String> imagesToShow = _property!.imageUrls.isNotEmpty
        ? _property!.imageUrls.where((url) => url.isNotEmpty).toList()
        : (_property!.imageUrl.isNotEmpty ? [_property!.imageUrl] : []);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(flex: 45, child: _buildCarouselSection(imagesToShow)),
          Expanded(flex: 55, child: _buildContentSection()),
        ],
      ),
      bottomNavigationBar: _buildBottomButtons(),
    );
  }

  Widget _buildCarouselSection(List<String> imagesToShow) {
    return Stack(
      children: [
        PageView.builder(
          controller: _carouselController,
          itemCount: imagesToShow.length,
          physics: const ClampingScrollPhysics(),
          onPageChanged: (index) {
            if (mounted) {
              setState(() => _currentImageIndex = index);
            }
          },
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () => _openFullScreenGallery(imagesToShow, index),
              child: Image.network(
                imagesToShow[index],
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
                    onPressed: () => context.pop(),
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
                    onPressed: () => setState(() => _isFavorite = !_isFavorite),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (imagesToShow.length > 1)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: imagesToShow.asMap().entries.map((entry) {
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
        Positioned(
          bottom: 20,
          right: 16,
          child: GestureDetector(
            onTap: () =>
                _openFullScreenGallery(imagesToShow, _currentImageIndex),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.fullscreen,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContentSection() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(Styles.spacingLarge),
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
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFeatureItem(
                Icons.bed_outlined,
                '${_property!.bedrooms}',
                'Habit.',
              ),
              _buildFeatureItem(
                Icons.bathtub_outlined,
                '${_property!.bathrooms}',
                'Baños',
              ),
              _buildFeatureItem(
                Icons.square_foot,
                '${_property!.area.toStringAsFixed(0)} m²',
                'Área',
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
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
            _buildMapSection(),
            const SizedBox(height: 24),
          ],
          Text(
            'Contacto',
            style: TextStyles.subtitle.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildOwnerCard(),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: EdgeInsets.all(Styles.spacingLarge),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _contactOwner('call'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                foregroundColor: Colors.black87,
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.phone, size: 20),
                  SizedBox(height: 2),
                  Text('Llamar', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: _startInternalChat,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                foregroundColor: Styles.primaryColor,
                side: const BorderSide(color: Styles.primaryColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: Styles.primaryColor.withOpacity(0.05),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 20),
                  SizedBox(height: 2),
                  Text(
                    'Chat',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _contactOwner('whatsapp'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FaIcon(FontAwesomeIcons.whatsapp, size: 20),
                  SizedBox(height: 2),
                  Text(
                    'WhatsApp',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String value, String label) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(icon, color: Styles.primaryColor, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        ],
      ),
    );
  }

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

  Widget _buildOwnerCard() {
    final name = _ownerData?['displayName'] ?? 'Usuario Mobiliaria';
    final photoUrl = _ownerData?['photoURL'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Styles.primaryColor.withOpacity(0.1),
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null
                ? Text(
                    name[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 20,
                      color: Styles.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Propietario / Agente',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.chevron_right, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

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
