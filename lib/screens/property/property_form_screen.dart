import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'dart:io';
import 'dart:async';

import '../../providers/mobiliaria_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/theme.dart';
import '../../core/utils/property_constants.dart';
import '../../core/utils/firestore_data_loader.dart';
import '../../services/image_service.dart';
import '../../models/property.dart';
import '../../core/utils/amenity_helper.dart';

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

  Map<String, List<String>> _regions = {};
  bool _isLoadingCatalogs = true;
  bool _isSaving = false;
  bool _showError = false;

  Map<String, bool> _amenityState = {};
  List<String> _existingImageUrls = [];
  List<XFile> _newImageFiles = [];

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
          _selectedDepartment ??= _regions.keys.first;
          if (_selectedDepartment != null) {
            final zones = _regions[_selectedDepartment];
            _selectedZone ??= zones?.isNotEmpty == true ? zones!.first : null;
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
    final List<XFile> pickedFiles = await _picker.pickMultiImage(
      imageQuality: 70,
    );
    if (pickedFiles.isNotEmpty) {
      setState(() => _newImageFiles.addAll(pickedFiles));
    }
  }

  void _removeExistingImage(int index) =>
      setState(() => _existingImageUrls.removeAt(index));

  void _removeNewImage(int index) =>
      setState(() => _newImageFiles.removeAt(index));

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

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      // 1. Subir nuevas imágenes
      List<String> uploadedUrls = [];
      if (_newImageFiles.isNotEmpty) {
        uploadedUrls = await ImageService.uploadImages(
          _newImageFiles,
          'properties/${user.uid}',
        );
      }

      final allImageUrls = [..._existingImageUrls, ...uploadedUrls];
      final selectedAmenities = _amenityState.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
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
        'amenities': selectedAmenities,
        'imageUrls': allImageUrls,
        'owner_id': user.uid,
        'is_active': true,
      };

      // Obtener estado premium del usuario
      final authService = Provider.of<AuthService>(context, listen: false);
      final isPremium = authService.isPremium;

      final provider = Provider.of<MobiliariaProvider>(context, listen: false);
      await provider.saveProperty(
        propertyData,
        propertyId: _propertyToEdit?.id,
        isPremiumUser: isPremium,
      );

      if (mounted) {
        Modular.to.pop();
      }
    } catch (e) {
      // Error silencioso
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
              PropertyFormDetails(
                roomsController: _roomsController,
                bathroomsController: _bathroomsController,
                areaController: _areaController,
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
              const Text(
                'Comodidades',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              PropertyFormAmenities(
                amenityState: _amenityState,
                onAmenityChanged: (key, val) =>
                    setState(() => _amenityState[key] = val),
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
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
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
