import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart'; // <-- CORREGIDO: Usamos Modular
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'dart:io';

import '../../providers/mobiliaria_provider.dart';
import '../../theme/theme.dart';
import '../../core/utils/property_constants.dart';
import '../../core/utils/firestore_data_loader.dart';
import '../../services/image_service.dart';
import '../../models/property.dart';
import '../../core/utils/amenity_helper.dart';

// --- CONSTANTES DE MAPA (TOKEN REAL) ---
// Usamos las mismas que en el detalle y picker
const String _mapboxAccessToken =
    'pk.eyJ1IjoibXVqZXJlc2Fsdm9sYW50ZSIsImEiOiJjbWFoZTR1ZzEwYXdvMmtxMHg5ZXZneXgyIn0.9aNpyQyi5wP1qKi0SjiR5Q';
const String _mapboxStyleId = 'mapbox/streets-v12';

class PropertyFormScreen extends StatefulWidget {
  // Nota: Modular pasa argumentos en Modular.args.data, pero esta estructura es común para testing
  final Property? propertyToEdit;

  const PropertyFormScreen({super.key, this.propertyToEdit});

  @override
  State<PropertyFormScreen> createState() => _PropertyFormScreenState();
}

class _PropertyFormScreenState extends State<PropertyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  // Controladores
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

  Map<String, bool> _amenityState = {};
  List<String> _existingImageUrls = [];
  List<XFile> _newImageFiles = [];

  // Usar Modular.args.data para inicializar si es edición
  Property? get _propertyToEdit => Modular.args.data is Property
      ? Modular.args.data as Property
      : widget.propertyToEdit;

  @override
  void initState() {
    super.initState();
    _loadCatalogs();

    _amenityState = Map.fromIterable(
      PropertyConstants.amenityLabels.keys,
      key: (key) => key,
      value: (key) => false,
    );

    // Usamos _propertyToEdit (que considera Modular.args)
    if (_propertyToEdit != null) {
      _initializeForEdit(_propertyToEdit!);
    } else {
      _selectedTransactionType = PropertyConstants.transactionTypes.first;
      _selectedPropertyType = PropertyConstants.propertyTypes.first;
      _selectedCurrency = PropertyConstants.currencies.first;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _roomsController.dispose();
    _bathroomsController.dispose();
    _areaController.dispose();
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
    final loader = FirestoreDataLoader();
    final regions = await loader.loadRegions();
    if (mounted) {
      setState(() {
        _regions = regions;
        _isLoadingCatalogs = false;

        // Lógica de reseteo o validación de selección
        if (_selectedDepartment != null &&
            !_regions.containsKey(_selectedDepartment)) {
          _selectedDepartment = null;
          _selectedZone = null;
        }
        if (_selectedDepartment != null && _selectedZone != null) {
          final zones = _regions[_selectedDepartment] ?? [];
          if (!zones.contains(_selectedZone)) _selectedZone = null;
        }

        if (_propertyToEdit == null) {
          if (_selectedDepartment == null && _regions.keys.isNotEmpty) {
            _selectedDepartment = _regions.keys.first;
          }
          if (_selectedDepartment != null && _selectedZone == null) {
            _selectedZone = _regions[_selectedDepartment]?.isNotEmpty == true
                ? _regions[_selectedDepartment]!.first
                : null;
          }
        }
      });
    }
  }

  Future<void> _pickImages() async {
    final List<XFile> pickedFiles = await _picker.pickMultiImage(
      imageQuality: 70,
    );
    if (pickedFiles.isNotEmpty)
      setState(() => _newImageFiles.addAll(pickedFiles));
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
    // CORREGIDO: Usamos Modular.to.pushNamed
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

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(
        () =>
            _currentGeopoint = GeoPoint(position.latitude, position.longitude),
      );
    } catch (e) {
      // Error silencioso
    }
  }

  Future<void> _saveProperty() async {
    if (!_formKey.currentState!.validate()) return;
    if (_existingImageUrls.isEmpty && _newImageFiles.isEmpty) {
      return;
    }
    if (_currentGeopoint == null) {
      return;
    }

    final provider = Provider.of<MobiliariaProvider>(context, listen: false);
    List<String> uploadedUrls = [];
    String propertyId =
        _propertyToEdit?.id ?? // Usamos _propertyToEdit
        FirebaseFirestore.instance.collection('properties').doc().id;

    try {
      if (_newImageFiles.isNotEmpty) {
        for (var file in _newImageFiles) {
          final url = await ImageService.uploadImageToApi(
            file,
            folderPath: '${ImageService.IMAGE_PROPERTY_FOLDER}/$propertyId',
          );
          uploadedUrls.add(url);
        }
      }
    } catch (e) {
      return;
    }

    final allImageUrls = List<String>.from(_existingImageUrls)
      ..addAll(uploadedUrls);

    Map<String, bool> finalAmenities = {};
    _amenityState.forEach((key, value) {
      if (value) finalAmenities[key] = true;
    });

    // Obtener datos del usuario actual
    final user = FirebaseAuth.instance.currentUser;
    Map<String, dynamic>? userData;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      userData = userDoc.data();
    }

    final propertyData = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'price': double.tryParse(_priceController.text.trim()) ?? 0,
      'currency': _selectedCurrency,
      'transaction_type': _selectedTransactionType,
      'property_type': _selectedPropertyType,
      'rooms': int.tryParse(_roomsController.text.trim()) ?? 0,
      'bathrooms': int.tryParse(_bathroomsController.text.trim()) ?? 0,
      'area_sqm': double.tryParse(_areaController.text.trim()) ?? 0,
      'department': _selectedDepartment,
      'zone_key': _selectedZone,
      'geopoint': _currentGeopoint,
      'imageUrls': allImageUrls,
      'amenities': finalAmenities,
      // Agregar datos de empresa si es inmobiliaria
      if (userData?['role'] == 'inmobiliaria_empresa') ...{
        'publisherType': 'company',
        'companyId': user?.uid,
        'companyName': userData?['companyName'],
        'companyLogo': userData?['companyLogo'],
      } else ...{
        'publisherType': 'user',
      },
      'status': 'active',
    };

    final success = await provider.saveProperty(
      propertyData,
      propertyId: _propertyToEdit?.id, // Usamos _propertyToEdit
    );

    if (mounted) {
      if (success) {
        // Redirigir según el rol del usuario
        if (userData?['role'] == 'inmobiliaria_empresa') {
          Modular.to.navigate('/inmobiliaria/properties');
        } else {
          Modular.to.navigate('/property/my');
        }
      }
    }
  }

  // --- ESTILOS ---
  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Styles.primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Styles.errorColor),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _propertyToEdit != null; // Usamos _propertyToEdit
    final provider = Provider.of<MobiliariaProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          isEditing ? 'Editar Propiedad' : 'Nueva Publicación',
          style: const TextStyle(
            color: Styles.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Styles.textPrimary),
        leading: IconButton(
          icon: const Icon(Icons.close, size: 20),
          // CORREGIDO: Usamos Modular.to.pop()
          onPressed: () => Modular.to.pop(),
        ),
      ),
      body: _isLoadingCatalogs
          ? const Center(
              child: CircularProgressIndicator(color: Styles.primaryColor),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(Styles.spacingLarge),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Galería', Icons.photo_library),
                    const SizedBox(height: 12),
                    _buildImagePicker(),
                    SizedBox(height: Styles.spacingLarge),

                    _buildSectionHeader(
                      'Información Básica',
                      Icons.info_outline,
                    ),
                    const SizedBox(height: 12),
                    _buildLabel('Título'),
                    TextFormField(
                      controller: _titleController,
                      maxLength: 100,
                      decoration: _buildInputDecoration(
                        'Ej: Casa moderna en el centro',
                      ),
                      validator: (v) => v!.isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildLabel('Descripción'),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      maxLength: 500,
                      decoration: _buildInputDecoration(
                        'Detalla los puntos fuertes...',
                      ),
                      validator: (v) => v!.isEmpty ? 'Requerido' : null,
                    ),
                    SizedBox(height: Styles.spacingLarge),

                    _buildSectionHeader(
                      'Detalles del Inmueble',
                      Icons.home_work,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Transacción'),
                              _buildDropdown(
                                'Selecciona',
                                _selectedTransactionType,
                                PropertyConstants.transactionTypes,
                                (v) => setState(
                                  () => _selectedTransactionType = v,
                                ),
                                (t) => Text(
                                  PropertyConstants.getTransactionTitle(t),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Tipo'),
                              _buildDropdown(
                                'Selecciona',
                                _selectedPropertyType,
                                PropertyConstants.propertyTypes,
                                (v) =>
                                    setState(() => _selectedPropertyType = v),
                                (t) =>
                                    Text(PropertyConstants.getPropertyTitle(t)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: Styles.spacingLarge),

                    _buildSectionHeader('Ubicación', Icons.map_outlined),
                    const SizedBox(height: 12),
                    _buildRegionSelectors(),
                    const SizedBox(height: 12),
                    // MÓDULO DE MAPA MEJORADO
                    _buildMapModule(),
                    SizedBox(height: Styles.spacingLarge),

                    _buildSectionHeader(
                      'Precio y Dimensiones',
                      Icons.attach_money,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Precio'),
                              TextFormField(
                                controller: _priceController,
                                keyboardType: TextInputType.number,
                                decoration: _buildInputDecoration('0.00'),
                                validator: (v) => v!.isEmpty ? '*' : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Moneda'),
                              _buildDropdown(
                                'M',
                                _selectedCurrency,
                                PropertyConstants.currencies,
                                (v) => setState(() => _selectedCurrency = v),
                                (c) => Text(c),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Habitaciones'),
                              TextFormField(
                                controller: _roomsController,
                                keyboardType: TextInputType.number,
                                decoration: _buildInputDecoration('Ej: 3'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Baños'),
                              TextFormField(
                                controller: _bathroomsController,
                                keyboardType: TextInputType.number,
                                decoration: _buildInputDecoration('Ej: 2'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Área (m²)'),
                              TextFormField(
                                controller: _areaController,
                                keyboardType: TextInputType.number,
                                decoration: _buildInputDecoration('Ej: 120'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: Styles.spacingLarge),

                    _buildSectionHeader('Comodidades', Icons.star_border),
                    const SizedBox(height: 12),
                    _buildAmenitiesCheckboxes(),
                    SizedBox(height: Styles.spacingXLarge),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: provider.isLoading ? null : _saveProperty,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Styles.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: provider.isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                isEditing
                                    ? 'Guardar Cambios'
                                    : 'Publicar Anuncio',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(height: Styles.spacingMedium),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Styles.primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Styles.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6, left: 2),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.black87,
      ),
    ),
  );

  Widget _buildDropdown<T>(
    String hint,
    T? value,
    List<T> items,
    ValueChanged<T?> onChanged,
    Widget Function(T) itemBuilder,
  ) {
    final T? effectiveValue = items.contains(value) ? value : null;
    return DropdownButtonFormField<T>(
      value: effectiveValue,
      decoration: _buildInputDecoration(hint),
      isExpanded: true,
      items: items
          .map(
            (T val) => DropdownMenuItem<T>(value: val, child: itemBuilder(val)),
          )
          .toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? 'Requerido' : null,
    );
  }

  Widget _buildRegionSelectors() {
    final List<String> departments = _regions.keys.toList();
    final List<String> zones =
        (_selectedDepartment != null &&
            _regions.containsKey(_selectedDepartment))
        ? _regions[_selectedDepartment]!
        : [];

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Departamento'),
              _buildDropdown('Selecciona', _selectedDepartment, departments, (
                val,
              ) {
                setState(() {
                  _selectedDepartment = val;
                  // Reseteamos la zona al cambiar de departamento
                  _selectedZone = _regions[val]?.isNotEmpty == true
                      ? _regions[val]!.first
                      : null;
                });
              }, (d) => Text(d)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Zona'),
              _buildDropdown(
                'Selecciona',
                _selectedZone,
                zones,
                (val) => setState(() => _selectedZone = val),
                (z) => Text(z),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- UI: MAPA MEJORADO ---
  Widget _buildMapModule() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Área del Mapa Visual
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              height: 200,
              color: Colors.grey.shade100,
              child: _currentGeopoint == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.map_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ubicación no definida',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          TextButton.icon(
                            onPressed: _selectLocationOnMap,
                            icon: const Icon(Icons.add_location_alt),
                            label: const Text('Seleccionar en Mapa'),
                          ),
                        ],
                      ),
                    )
                  : Stack(
                      children: [
                        // Mapa Estático (Preview)
                        FlutterMap(
                          // Usamos ValueKey para forzar reconstrucción si cambia el punto
                          key: ValueKey(_currentGeopoint),
                          options: MapOptions(
                            initialCenter: LatLng(
                              _currentGeopoint!.latitude,
                              _currentGeopoint!.longitude,
                            ),
                            initialZoom: 15,
                            // Desactivamos interacción para que no interfiera con el scroll del formulario
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.none,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://api.mapbox.com/styles/v1/$_mapboxStyleId/tiles/256/{z}/{x}/{y}@2x?access_token=$_mapboxAccessToken',
                              userAgentPackageName: 'com.mobiliaria.app',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(
                                    _currentGeopoint!.latitude,
                                    _currentGeopoint!.longitude,
                                  ),
                                  width: 40,
                                  height: 40,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Styles.primaryColor,
                                    size: 40,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Capa transparente para detectar toque y abrir el picker completo
                        Positioned.fill(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(onTap: _selectLocationOnMap),
                          ),
                        ),
                        // Botón de editar superpuesto
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: FloatingActionButton.small(
                            heroTag: 'edit_map_btn',
                            onPressed: _selectLocationOnMap,
                            backgroundColor: Colors.white,
                            child: const Icon(
                              Icons.edit_location_alt,
                              color: Styles.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          // Barra inferior con coordenadas y botón rápido de GPS
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Punto seleccionado',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        _currentGeopoint != null
                            ? '${_currentGeopoint!.latitude.toStringAsFixed(4)}, ${_currentGeopoint!.longitude.toStringAsFixed(4)}'
                            : 'Ninguno',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _getCurrentLocation,
                  icon: const Icon(Icons.my_location, size: 16),
                  label: const Text(
                    'Usar mi GPS',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickImages,
          child: Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: Styles.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Styles.primaryColor.withOpacity(0.3),
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 32,
                  color: Styles.primaryColor,
                ),
                const SizedBox(height: 8),
                Text(
                  'Toca para añadir fotos',
                  style: TextStyle(
                    color: Styles.primaryColor.withOpacity(0.8),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_existingImageUrls.isNotEmpty || _newImageFiles.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ..._existingImageUrls.asMap().entries.map(
                  (e) => _buildImageThumbnail(
                    NetworkImage(e.value),
                    () => _removeExistingImage(e.key),
                  ),
                ),
                ..._newImageFiles.asMap().entries.map(
                  (e) => _buildImageThumbnail(
                    Image.file(File(e.value.path)).image,
                    () => _removeNewImage(e.key),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildImageThumbnail(ImageProvider image, VoidCallback onDelete) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(image: image, fit: BoxFit.cover),
              border: Border.all(color: Colors.grey.shade300),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmenitiesCheckboxes() {
    return Column(
      children: AmenityHelper.amenityCategories.entries.map((category) {
        final validKeys = category.value
            .where((key) => PropertyConstants.amenityLabels.containsKey(key))
            .toList();

        final selectedCount = validKeys
            .where((key) => _amenityState[key] == true)
            .length;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Styles.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  AmenityHelper.getCategoryIcon(category.key),
                  color: Styles.primaryColor,
                  size: 20,
                ),
              ),
              title: Text(
                category.key,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Styles.textPrimary,
                ),
              ),
              subtitle: selectedCount > 0
                  ? Text(
                      '$selectedCount seleccionados',
                      style: const TextStyle(
                        color: Styles.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : const Text(
                      'Toque para desplegar',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Divider(color: Colors.grey.shade100),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: validKeys.map((key) {
                    final label = PropertyConstants.amenityLabels[key]!;
                    final isSelected = _amenityState[key] == true;

                    return FilterChip(
                      avatar: isSelected
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : Icon(
                              AmenityHelper.getIcon(key),
                              size: 18,
                              color: Colors.grey[600],
                            ),
                      label: Text(label),
                      selected: isSelected,
                      onSelected: (v) => setState(() => _amenityState[key] = v),
                      selectedColor: Styles.primaryColor,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                      backgroundColor: Colors.grey[50],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isSelected
                              ? Colors.transparent
                              : Colors.grey.shade300,
                        ),
                      ),
                      showCheckmark: false,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
