import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chaski_comercial/services/ad_service.dart';
import 'package:share_plus/share_plus.dart';
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
  final Map<String, bool> _premiumStatus =
      {}; // Para cachear estado premium de propietarios
  bool _isMapUnlocked = false; // Estado de desbloqueo del mapa

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

    final savedProperties = await _savedListService.getAllSavedProperties(
      userId,
    );

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
          .where('property_type', isEqualTo: _property!.propertyTypeRaw);

      final snapshot = await query.get();
      var properties = snapshot.docs
          .where(
            (doc) =>
                doc.id != widget.propertyId &&
                (doc.data()['available'] ?? true),
          )
          .map((doc) => Property.fromFirestore(doc))
          .toList();

      properties.sort((a, b) {
        final aDate = a.lastPublishedAt ?? a.createdAt ?? DateTime(2000);
        final bDate = b.lastPublishedAt ?? b.createdAt ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });

      // Mezclar aleatoriamente TODAS las propiedades
      properties.shuffle();

      // Cargar estado premium de los propietarios
      for (final property in properties) {
        await _checkOwnerPremiumStatus(property.ownerId);
      }

      if (mounted) {
        setState(() {
          _similarProperties = properties;
        });
      }
    } catch (e) {
      debugPrint('Error cargando propiedades similares: $e');
    }
  }

  // Verificar si un propietario es premium
  Future<void> _checkOwnerPremiumStatus(String ownerId) async {
    if (_premiumStatus.containsKey(ownerId)) {
      return; // Ya lo tenemos cacheado
    }

    try {
      final premiumDoc = await FirebaseFirestore.instance
          .collection('premium_users')
          .doc(ownerId)
          .get();

      final isPremium =
          premiumDoc.exists &&
          (premiumDoc.data()?['status'] == 'active' ||
              premiumDoc.data()?['premium'] == true);

      _premiumStatus[ownerId] = isPremium;
    } catch (e) {
      debugPrint('Error checking premium status for $ownerId: $e');
      _premiumStatus[ownerId] = false;
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

        // Verificar si el owner es premium
        await _checkOwnerPremiumStatus(_property!.ownerId);
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

  Future<String?> _showPhonePicker(List<String> phones) async {
    return await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Seleccionar contacto',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'El propietario tiene varios números registrados. Elige uno:',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 20),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: phones.length,
                    itemBuilder: (context, index) {
                      final phone = phones[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Styles.primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.phone_outlined,
                              color: Styles.primaryColor,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            phone,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: Colors.grey.shade400,
                            size: 20,
                          ),
                          onTap: () => Navigator.pop(context, phone),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _unlockMapWithAd() async {
    if (_isMapUnlocked) return;

    try {
      await AdService.instance.showInterstitialThen(() async {
        if (mounted) {
          setState(() {
            _isMapUnlocked = true;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo mostrar el anuncio: $e')),
        );
      }
    }
    return;
  }

  // Implementación del método de contacto desde la interfaz
  @override
  Future<void> contactOwner(String type) async {
    if (_ownerData == null) return;

    final mainPhone = _ownerData?['phoneNumber'] as String? ?? '';
    final extraNumbers = _ownerData?['extraContactNumbers'] as Map? ?? {};
    final allPhones = <String>[];

    if (mainPhone.isNotEmpty) allPhones.add(mainPhone);
    for (var v in extraNumbers.values) {
      final s = v.toString();
      if (s.isNotEmpty && !allPhones.contains(s)) {
        allPhones.add(s);
      }
    }

    if (allPhones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El propietario no tiene teléfono registrado'),
        ),
      );
      return;
    }

    String? phone;
    if (allPhones.length > 1) {
      phone = await _showPhonePicker(allPhones);
      if (phone == null) return; // El usuario canceló la selección
    } else {
      phone = allPhones.first;
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
      await AdService.instance.showInterstitialThen(() async {
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          throw 'No se pudo lanzar $uri';
        }
      });
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

  // Compartir propiedad
  Future<void> _shareProperty() async {
    if (_property == null) return;

    final propertyUrl = 'comercial://property/${widget.propertyId}';
    final message =
        '¡Mira esta propiedad!\n\n'
        '${_property!.name}\n'
        '${_property!.price}\n'
        '${_property!.location}\n\n'
        'Abre en la app: $propertyUrl';

    try {
      await Share.share(message, subject: _property!.name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al compartir: $e')));
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
            'otherUserPhoto':
                _ownerData?['photoURL'] ?? _ownerData?['photoUrl'],
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

  // Sección de links de anunciadores
  Widget _buildAdvertiserLinksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.link, color: Styles.primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              'Enlaces Externos',
              style: TextStyles.subtitle.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Styles.primaryColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Styles.primaryColor.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Esta propiedad también está publicada en:',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              ...(_property!.advertiserLinks.asMap().entries.map((entry) {
                final index = entry.key;
                final link = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: InkWell(
                    onTap: () async {
                      final uri = Uri.parse(link);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Styles.primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.open_in_new,
                              size: 14,
                              color: Styles.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Enlace ${index + 1}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  link,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Styles.primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList()),
            ],
          ),
        ),
      ],
    );
  }

  // Sección de números de contacto adicionales
  Widget _buildExtraContactNumbersSection() {
    final extraNumbers = _ownerData?['extraContactNumbers'] as Map? ?? {};
    if (extraNumbers.isEmpty) return const SizedBox.shrink();

    final phonesList = extraNumbers.values
        .map((v) => v.toString())
        .where((s) => s.isNotEmpty)
        .toList();

    if (phonesList.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.phone_in_talk, color: Styles.primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              'Números de Contacto Adicionales',
              style: TextStyles.subtitle.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'También puedes contactar al propietario en:',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              ...(phonesList.asMap().entries.map((entry) {
                final index = entry.key;
                final phone = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: InkWell(
                    onTap: () async {
                      final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
                      final finalPhone =
                          (cleanPhone.length == 8 &&
                              !cleanPhone.startsWith('591'))
                          ? '591$cleanPhone'
                          : cleanPhone;
                      final uri = Uri.parse("tel:$finalPhone");
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.phone,
                              size: 14,
                              color: Colors.green.shade700,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Número ${index + 1}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  phone,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.call,
                            size: 16,
                            color: Colors.green.shade600,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList()),
            ],
          ),
        ),
      ],
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
          if (_property!.advertiserLinks.isNotEmpty) ...[
            _buildAdvertiserLinksSection(),
            const SizedBox(height: 24),
          ],
          if (_ownerData != null) ...[
            _buildExtraContactNumbersSection(),
            const SizedBox(height: 24),
          ],
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
              'Propiedades Similares',
              style: TextStyles.subtitle.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                // Quitamos el const aquí
                crossAxisCount: 2,
                // SI la pantalla es menor a 400px (móviles pequeños), usa 0.70 (más alto).
                // SI es mayor, usa 0.85 (tu diseño original).
                childAspectRatio: MediaQuery.of(context).size.width < 400
                    ? 0.70
                    : 0.85,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _similarProperties.length,
              itemBuilder: (context, index) {
                final property = _similarProperties[index];
                final isPremium = _premiumStatus[property.ownerId] ?? false;

                return CompactPropertyCard(
                  property: property,
                  isFavorite: _savedPropertyIds.contains(property.id),
                  showGoldenBorder: isPremium,
                  onFavoriteToggle: () => _openCollectionDialog(property),
                  onTap: () => Modular.to.pushNamed(
                    '/property/detail/${property.id}',
                    arguments: property,
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
                  Row(
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
                          icon: const Icon(Icons.share, color: Colors.black),
                          onPressed: _shareProperty,
                        ),
                      ),
                      const SizedBox(width: 8),
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
                            _isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: _isFavorite ? Colors.red : Colors.black,
                          ),
                          onPressed: _toggleFavorite,
                        ),
                      ),
                    ],
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

    // Verificar si el owner es premium
    final isOwnerPremium = _premiumStatus[_property!.ownerId] ?? false;
    final isMapUnlocked = isOwnerPremium || _isMapUnlocked;

    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Mapa original
            FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(lat, lng),
                initialZoom: 15.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none, // Deshabilitar interacción
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
            // Mostrar blur y overlay solo si el mapa NO está desbloqueado
            if (!isMapUnlocked) ...[
              // Efecto de blur sobre el mapa
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                  child: Container(color: Colors.black.withOpacity(0.1)),
                ),
              ),
              // Overlay clickeable con candado y mensaje
              Positioned.fill(
                child: GestureDetector(
                  onTap: _unlockMapWithAd,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.play_circle_outline,
                          size: 48,
                          color: Styles.primaryColor,
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'Toca para ver anuncio y\ndesbloquear la ubicación',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Styles.primaryColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'VER ANUNCIO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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
              ownerId: _property!.ownerId,
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

  @override
  void initState() {
    super.initState();
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
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _controller.value.isPlaying
              ? _controller.pause()
              : _controller.play();
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
