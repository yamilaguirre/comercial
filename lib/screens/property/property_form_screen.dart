import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';

import '../../providers/mobiliaria_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/theme.dart';
import '../../core/utils/property_constants.dart';
import '../../core/utils/firestore_data_loader.dart';
import '../../services/image_service.dart';
import '../../services/video_service.dart';
import '../../models/property.dart';

// Components
import 'components/form/property_form_progress_bar.dart';
import 'components/form/property_form_image_picker.dart';
import 'components/form/property_form_basic_info.dart';
import 'components/form/property_form_type_selector.dart';
import 'components/form/property_form_details.dart';
import 'components/form/property_form_location.dart';
import 'components/form/property_form_amenities.dart';

class PropertyFormScreen extends StatefulWidget {
  final Property? propertyToEdit;

  const PropertyFormScreen({super.key, this.propertyToEdit});

  @override
  State<PropertyFormScreen> createState() => _PropertyFormScreenState();
}

class _PropertyFormScreenState extends State<PropertyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _scrollController = ScrollController();

  // Debounce timers for performance
  Timer? _titleDebounce;
  Timer? _descriptionDebounce;
  Timer? _priceDebounce;

  // Controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _roomsController = TextEditingController();
  final _bathroomsController = TextEditingController();
  final _areaController = TextEditingController();

  String? _selectedTransactionType;
  String? _selectedPropertyType;
  String? _selectedCurrency;
  String? _selectedDepartment;
  String? _selectedZone;
  GeoPoint? _currentGeopoint;

  final List<TextEditingController> _extraContactControllers = [];
  final List<TextEditingController> _advertiserLinkControllers = [];

  Map<String, List<String>> _regions = {};
  bool _isLoadingCatalogs = true;
  bool _isSaving = false;
  bool _showError = false;
  String _savingStatus = '';

  Map<String, bool> _amenityState = {};
  List<String> _existingImageUrls = [];
  List<XFile> _newImageFiles = [];
  List<String> _existingVideoUrls = [];
  List<XFile> _newVideoFiles = [];

  Property? get _propertyToEdit => Modular.args.data is Property
      ? Modular.args.data as Property
      : widget.propertyToEdit;

  bool get isEditing => _propertyToEdit != null;

  // Progress calculation
  int get completedSteps {
    int count = 0;
    if (_existingImageUrls.isNotEmpty || _newImageFiles.isNotEmpty) count++;
    if (_selectedTransactionType != null) count++;
    if (_selectedPropertyType != null) count++;
    if (_priceController.text.isNotEmpty) count++;
    if (_titleController.text.isNotEmpty) count++;
    if (_descriptionController.text.isNotEmpty) count++;
    if (_selectedDepartment != null && _selectedZone != null) count++;
    if (_currentGeopoint != null) count++;
    return count;
  }

  double get progress => completedSteps / 8;

  int get totalMediaCount =>
      _existingImageUrls.length +
      _newImageFiles.length +
      _existingVideoUrls.length +
      _newVideoFiles.length;

  @override
  void initState() {
    super.initState();
    _loadCatalogs();

    _amenityState = Map.fromIterable(
      PropertyConstants.amenityLabels.keys,
      key: (key) => key,
      value: (key) => false,
    );

    if (_propertyToEdit != null) {
      _initializeForEdit(_propertyToEdit!);
    } else {
      _selectedTransactionType = PropertyConstants.transactionTypes.first;
      _selectedPropertyType = PropertyConstants.propertyTypes.first;
      _selectedCurrency = PropertyConstants.currencies.first;
    }

    // Inicializar números de contacto extra desde el perfil
    final authService = Provider.of<AuthService>(context, listen: false);
    authService.extraContactNumbers.forEach((key, value) {
      _extraContactControllers.add(TextEditingController(text: value));
    });

    // Add debounced listeners for better performance
    _titleController.addListener(_onTitleChanged);
    _descriptionController.addListener(_onDescriptionChanged);
    _priceController.addListener(_onPriceChanged);
  }

  void _onTitleChanged() {
    _titleDebounce?.cancel();
    _titleDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() {});
    });
  }

  void _onDescriptionChanged() {
    _descriptionDebounce?.cancel();
    _descriptionDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() {});
    });
  }

  void _onPriceChanged() {
    _priceDebounce?.cancel();
    _priceDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _titleDebounce?.cancel();
    _descriptionDebounce?.cancel();
    _priceDebounce?.cancel();
    _titleController.removeListener(_onTitleChanged);
    _descriptionController.removeListener(_onDescriptionChanged);
    _priceController.removeListener(_onPriceChanged);
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _roomsController.dispose();
    _bathroomsController.dispose();
    _areaController.dispose();
    for (var c in _extraContactControllers) {
      c.dispose();
    }
    for (var c in _advertiserLinkControllers) {
      c.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeForEdit(Property property) {
    _titleController.text = property.name;
    _descriptionController.text = property.description;
    _priceController.text = property.price.replaceAll(RegExp(r'[^\d.]'), '');
    _roomsController.text = property.bedrooms.toString();
    _bathroomsController.text = property.bathrooms.toString();
    _areaController.text = property.area.toStringAsFixed(0);

    _selectedTransactionType = property.type;
    _selectedPropertyType = PropertyConstants.propertyTypes.firstWhere(
      (type) => type == property.propertyTypeRaw,
      orElse: () => PropertyConstants.propertyTypes.first,
    );

    _selectedCurrency = property.price.contains('USD') ? 'USD' : 'BS';
    _selectedDepartment = property.department;
    _selectedZone = property.zone;
    _currentGeopoint = property.geopoint;
    _existingImageUrls = List.from(property.imageUrls);
    _existingVideoUrls = List.from(property.videoUrls);

    // Inicializar links de anunciadores
    for (final link in property.advertiserLinks) {
      _advertiserLinkControllers.add(TextEditingController(text: link));
    }

    for (var key in property.amenities) {
      if (_amenityState.containsKey(key)) _amenityState[key] = true;
    }
  }

  Future<void> _loadCatalogs() async {
    try {
      final loader = FirestoreDataLoader();
      final regions = await loader.loadRegions();

      if (!mounted) return;

      setState(() {
        _regions = regions;
        _isLoadingCatalogs = false;

        // Validar departamento
        if (_selectedDepartment != null &&
            !_regions.containsKey(_selectedDepartment)) {
          _selectedDepartment = null;
          _selectedZone = null;
        }

        // Validar zona
        if (_selectedDepartment != null && _selectedZone != null) {
          final zones = _regions[_selectedDepartment] ?? [];
          if (!zones.contains(_selectedZone)) {
            _selectedZone = zones.isNotEmpty ? zones.first : null;
          }
        }

        // Auto-seleccionar solo para nueva propiedad
        if (_propertyToEdit == null && _regions.isNotEmpty) {
          // Intentar establecer Cochabamba como valor por defecto
          if (_regions.containsKey('Cochabamba')) {
            _selectedDepartment ??= 'Cochabamba';
            final zones = _regions['Cochabamba'];
            // Intentar establecer Centro (Cercado) como valor por defecto
            if (zones != null && zones.contains('Centro (Cercado)')) {
              _selectedZone ??= 'Centro (Cercado)';
            } else if (zones?.isNotEmpty == true) {
              _selectedZone ??= zones!.first;
            }
          } else {
            // Fallback a primer departamento disponible
            _selectedDepartment ??= _regions.keys.first;
            if (_selectedDepartment != null) {
              final zones = _regions[_selectedDepartment];
              _selectedZone ??= zones?.isNotEmpty == true ? zones!.first : null;
            }
          }
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCatalogs = false);
      }
    }
  }

  Future<void> _pickImages() async {
    if (totalMediaCount >= 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Máximo 20 imágenes y videos en total')),
      );
      return;
    }
    final List<XFile> pickedFiles = await _picker.pickMultiImage(
      imageQuality: 70,
    );
    if (pickedFiles.isNotEmpty) {
      final remaining = 20 - totalMediaCount;
      setState(() => _newImageFiles.addAll(pickedFiles.take(remaining)));
    }
  }

  Future<void> _pickVideos() async {
    if (totalMediaCount >= 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Máximo 20 imágenes y videos en total')),
      );
      return;
    }
    if (_existingVideoUrls.length + _newVideoFiles.length >= 5) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Máximo 5 videos')));
      return;
    }
    final XFile? pickedFile = await _picker.pickVideo(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() => _newVideoFiles.add(pickedFile));
    }
  }

  void _removeExistingImage(int index) =>
      setState(() => _existingImageUrls.removeAt(index));

  void _removeNewImage(int index) =>
      setState(() => _newImageFiles.removeAt(index));

  void _removeExistingVideo(int index) =>
      setState(() => _existingVideoUrls.removeAt(index));

  void _removeNewVideo(int index) =>
      setState(() => _newVideoFiles.removeAt(index));

  Widget _buildVideoSection() {
    final hasVideos =
        _existingVideoUrls.isNotEmpty || _newVideoFiles.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Videos (opcional)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              '${_existingVideoUrls.length + _newVideoFiles.length}/5',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Agrega hasta 5 videos para mostrar mejor tu propiedad.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        if (!hasVideos)
          GestureDetector(
            onTap: _pickVideos,
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300, width: 1.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.videocam_outlined,
                    size: 32,
                    color: Styles.primaryColor,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Seleccionar videos',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Styles.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _existingVideoUrls.length + _newVideoFiles.length + 1,
              itemBuilder: (context, index) {
                if (index == 0 &&
                    (_existingVideoUrls.length + _newVideoFiles.length) < 5) {
                  return GestureDetector(
                    onTap: _pickVideos,
                    child: Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, size: 24, color: Styles.primaryColor),
                          const SizedBox(height: 4),
                          Text(
                            'Añadir',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Styles.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final videoIndex = index - 1;
                final isExisting = videoIndex < _existingVideoUrls.length;
                final displayIndex = isExisting
                    ? videoIndex
                    : videoIndex - _existingVideoUrls.length;
                return Stack(
                  children: [
                    Container(
                      width: 150,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.play_circle_outline,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 20,
                      child: GestureDetector(
                        onTap: () => isExisting
                            ? _removeExistingVideo(displayIndex)
                            : _removeNewVideo(displayIndex),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildContactNumbersSection() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final mainPhone = authService.phoneNumber ?? 'Sin número';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Números de Contacto',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              '${_extraContactControllers.length + 1}/5',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Estos números aparecerán en tu publicación para que te contacten.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.phone, color: Colors.green.shade600, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mainPhone,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Text(
                      'Número principal (de tu cuenta)',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ..._extraContactControllers.asMap().entries.map((entry) {
          int idx = entry.key;
          var controller = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Número adicional ${idx + 1}',
                      hintText: 'Ej. 70000000',
                      prefixIcon: const Icon(Icons.add_call, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _extraContactControllers[idx].dispose();
                      _extraContactControllers.removeAt(idx);
                    });
                  },
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: Colors.red,
                  ),
                  tooltip: 'Eliminar número',
                ),
              ],
            ),
          );
        }).toList(),
        if (_extraContactControllers.length < 4)
          Container(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _extraContactControllers.add(TextEditingController());
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Agregar número adicional'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: Styles.primaryColor),
                foregroundColor: Styles.primaryColor,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAdvertiserLinksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Links de Anunciador',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              'Opcional',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Agrega enlaces externos donde se publica esta propiedad (ej. OLX, Facebook Marketplace, etc.).',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        ..._advertiserLinkControllers.asMap().entries.map((entry) {
          int idx = entry.key;
          var controller = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Link ${idx + 1}',
                      hintText: 'Ej. https://www.olx.bo/...',
                      prefixIcon: const Icon(Icons.link, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _advertiserLinkControllers[idx].dispose();
                      _advertiserLinkControllers.removeAt(idx);
                    });
                  },
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: Colors.red,
                  ),
                  tooltip: 'Eliminar link',
                ),
              ],
            ),
          );
        }).toList(),
        Container(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _advertiserLinkControllers.add(TextEditingController());
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Agregar link de anunciador'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(color: Styles.primaryColor),
              foregroundColor: Styles.primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectLocationOnMap() async {
    Map<String, double>? extras;
    if (_currentGeopoint != null) {
      extras = {
        'lat': _currentGeopoint!.latitude,
        'lng': _currentGeopoint!.longitude,
      };
    }
    final LatLng? result = await Modular.to.pushNamed(
      '/property/map-picker',
      arguments: extras,
    );

    if (result != null) {
      setState(
        () => _currentGeopoint = GeoPoint(result.latitude, result.longitude),
      );
    }
  }

  Future<void> _saveProperty() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isRealEstateAgency = authService.userRole == 'inmobiliaria_empresa';

    // Validaciones adicionales para inmobiliarias
    if (isRealEstateAgency) {
      // Validar características principales
      if (_roomsController.text.isEmpty ||
          _bathroomsController.text.isEmpty ||
          _areaController.text.isEmpty ||
          int.tryParse(_roomsController.text) == null ||
          int.tryParse(_bathroomsController.text) == null ||
          double.tryParse(_areaController.text) == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Las inmobiliarias deben completar todas las características principales',
            ),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _showError = true;
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _showError = false);
        });
        return;
      }

      // Validar mínimo 5 amenidades
      final selectedAmenities = _amenityState.entries
          .where((e) => e.value)
          .length;
      if (selectedAmenities < 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Las inmobiliarias deben seleccionar al menos 5 comodidades (tienes $selectedAmenities)',
            ),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _showError = true;
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _showError = false);
        });
        return;
      }
    }

    if (!_formKey.currentState!.validate() ||
        (_existingImageUrls.isEmpty && _newImageFiles.isEmpty) ||
        _currentGeopoint == null) {
      setState(() {
        _showError = true;
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showError = false);
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _savingStatus = 'Preparando...';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      // 1. Subir nuevas imágenes
      List<String> uploadedUrls = [];
      if (_newImageFiles.isNotEmpty) {
        setState(
          () => _savingStatus =
              'Subiendo imágenes ${0}/${_newImageFiles.length}...',
        );
        for (int i = 0; i < _newImageFiles.length; i++) {
          final url = await ImageService.uploadImages([
            _newImageFiles[i],
          ], 'properties/${user.uid}');
          uploadedUrls.addAll(url);
          if (mounted)
            setState(
              () => _savingStatus =
                  'Subiendo imágenes ${i + 1}/${_newImageFiles.length}...',
            );
        }
      }

      // 2. Subir nuevos videos
      List<String> uploadedVideoUrls = [];
      if (_newVideoFiles.isNotEmpty) {
        for (int i = 0; i < _newVideoFiles.length; i++) {
          if (mounted)
            setState(
              () => _savingStatus =
                  'Subiendo video ${i + 1}/${_newVideoFiles.length}...',
            );
          final url = await VideoService.uploadVideo(
            _newVideoFiles[i],
            'properties/${user.uid}',
          );
          uploadedVideoUrls.add(url);
        }
      }

      final allImageUrls = [..._existingImageUrls, ...uploadedUrls];
      final allVideoUrls = [..._existingVideoUrls, ...uploadedVideoUrls];

      // Convertir amenities a Map en lugar de List
      // Firestore espera: {"wifi": true, "parking": true}
      final amenitiesMap = Map<String, bool>.fromEntries(
        _amenityState.entries.where((entry) => entry.value),
      );

      // Recolectar links de anunciadores
      final advertiserLinks = _advertiserLinkControllers
          .map((ctrl) => ctrl.text.trim())
          .where((link) => link.isNotEmpty)
          .toList();

      final propertyData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': _priceController.text.trim(),
        'currency': _selectedCurrency,
        'transaction_type': _selectedTransactionType,
        'property_type': _selectedPropertyType,
        'rooms': int.tryParse(_roomsController.text) ?? 0,
        'bathrooms': int.tryParse(_bathroomsController.text) ?? 0,
        'area_sqm': double.tryParse(_areaController.text) ?? 0.0,
        'department': _selectedDepartment,
        'zone_key': _selectedZone,
        'geopoint': _currentGeopoint,
        'amenities': amenitiesMap,
        'imageUrls': allImageUrls,
        'videoUrls': allVideoUrls,
        'advertiserLinks': advertiserLinks,
        'owner_id': user.uid,
        'is_active': true,
      };

      if (mounted) setState(() => _savingStatus = 'Guardando propiedad...');

      // Obtener estado premium del usuario
      final authService = Provider.of<AuthService>(context, listen: false);
      final isPremium = authService.isPremium;

      final provider = Provider.of<MobiliariaProvider>(context, listen: false);
      await provider.saveProperty(
        propertyData,
        propertyId: _propertyToEdit?.id,
        isPremiumUser: isPremium,
      );

      // 3. Actualizar números extra en el perfil si hubo cambios
      final currentExtras = authService.extraContactNumbers;
      final newExtras = <String, String>{};
      for (int i = 0; i < _extraContactControllers.length; i++) {
        final val = _extraContactControllers[i].text.trim();
        if (val.isNotEmpty) {
          newExtras['phone_$i'] = val;
        }
      }

      // Comparar si son diferentes (simplificado)
      bool changed = currentExtras.length != newExtras.length;
      if (!changed) {
        for (var key in newExtras.keys) {
          if (currentExtras[key] != newExtras[key]) {
            changed = true;
            break;
          }
        }
      }

      if (changed) {
        if (mounted) setState(() => _savingStatus = 'Actualizando perfil...');
        await authService.updateUserProfile(extraContactNumbers: newExtras);
      }

      if (mounted) {
        Modular.to.pop();
      }
    } catch (e) {
      // Error silencioso
    } finally {
      if (mounted)
        setState(() {
          _isSaving = false;
          _savingStatus = '';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isEditing ? 'Editar Propiedad' : 'Nueva Propiedad',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: -0.5,
              ),
            ),
            if (!isEditing)
              Text(
                'Paso ${completedSteps > 8 ? 8 : completedSteps} de 8',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: PropertyFormProgressBar(progress: progress),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(20),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PropertyFormImagePicker(
                existingImageUrls: _existingImageUrls,
                newImageFiles: _newImageFiles,
                onPickImages: _pickImages,
                onRemoveExisting: _removeExistingImage,
                onRemoveNew: _removeNewImage,
              ),
              const SizedBox(height: 32),
              _buildAdvertiserLinksSection(),
              const SizedBox(height: 24),
              Consumer<AuthService>(
                builder: (context, authService, _) {
                  if (authService.isPremium) {
                    return Column(
                      children: [
                        _buildVideoSection(),
                        const SizedBox(height: 32),
                      ],
                    );
                  }
                  return const SizedBox(height: 32);
                },
              ),
              _buildContactNumbersSection(),
              const SizedBox(height: 32),
              PropertyFormBasicInfo(
                selectedTransactionType: _selectedTransactionType,
                titleController: _titleController,
                descriptionController: _descriptionController,
                priceController: _priceController,
                selectedCurrency: _selectedCurrency,
                onTransactionTypeChanged: (val) =>
                    setState(() => _selectedTransactionType = val),
                onCurrencyChanged: (val) =>
                    setState(() => _selectedCurrency = val),
              ),
              const SizedBox(height: 32),
              PropertyFormTypeSelector(
                selectedType: _selectedPropertyType,
                onTypeChanged: (val) =>
                    setState(() => _selectedPropertyType = val),
              ),
              const SizedBox(height: 32),
              PropertyFormLocation(
                selectedDepartment: _selectedDepartment,
                selectedZone: _selectedZone,
                currentGeopoint: _currentGeopoint,
                regions: _regions,
                isLoadingCatalogs: _isLoadingCatalogs,
                onDepartmentChanged: (val) {
                  setState(() {
                    _selectedDepartment = val;
                    if (val != null && _regions[val]?.isNotEmpty == true) {
                      _selectedZone = _regions[val]!.first;
                    } else {
                      _selectedZone = null;
                    }
                  });
                },
                onZoneChanged: (val) => setState(() => _selectedZone = val),
                onSelectLocation: _selectLocationOnMap,
              ),
              const SizedBox(height: 32),
              Consumer<AuthService>(
                builder: (context, authService, _) {
                  return PropertyFormDetails(
                    roomsController: _roomsController,
                    bathroomsController: _bathroomsController,
                    areaController: _areaController,
                    isRequired: authService.userRole == 'inmobiliaria_empresa',
                  );
                },
              ),
              const SizedBox(height: 32),
              Consumer<AuthService>(
                builder: (context, authService, _) {
                  final isRealEstateAgency =
                      authService.userRole == 'inmobiliaria_empresa';
                  final selectedCount = _amenityState.entries
                      .where((e) => e.value)
                      .length;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Comodidades',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              if (isRealEstateAgency) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Obligatorio',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (isRealEstateAgency)
                            Text(
                              '$selectedCount/5 mín.',
                              style: TextStyle(
                                fontSize: 14,
                                color: selectedCount >= 5
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                      if (isRealEstateAgency) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Las inmobiliarias deben seleccionar al menos 5 comodidades',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      PropertyFormAmenities(
                        amenityState: _amenityState,
                        onAmenityChanged: (key, val) =>
                            setState(() => _amenityState[key] = val),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 100), // Space for FAB
            ],
          ),
        ),
      ),
      floatingActionButton: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        width: double.infinity,
        child: FloatingActionButton.extended(
          onPressed: _isSaving ? null : _saveProperty,
          backgroundColor: _showError ? Colors.red : Styles.primaryColor,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          label: _isSaving
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        _savingStatus,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                )
              : Text(
                  _showError
                      ? 'Faltan campos'
                      : (isEditing ? 'Guardar Cambios' : 'Publicar Propiedad'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
          icon: _isSaving
              ? null
              : Icon(
                  _showError ? Icons.error_outline : Icons.check_circle_outline,
                  color: Colors.white,
                ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
