import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../providers/auth_provider.dart';
import '../../services/worker_location_service.dart';
import '../../models/worker_location_model.dart';
import '../../theme/theme.dart';

const String _mapboxAccessToken =
    'pk.eyJ1IjoibXVqZXJlc2Fsdm9sYW50ZSIsImEiOiJjbWFoZTR1ZzEwYXdvMmtxMHg5ZXZneXgyIn0.9aNpyQyi5wP1qKi0SjiR5Q';
const String _mapboxStyleId = 'mapbox/streets-v12';

class WorkerLocationConfigScreen extends StatefulWidget {
  const WorkerLocationConfigScreen({super.key});

  @override
  State<WorkerLocationConfigScreen> createState() =>
      _WorkerLocationConfigScreenState();
}

class _WorkerLocationConfigScreenState
    extends State<WorkerLocationConfigScreen> {
  final WorkerLocationService _locationService = WorkerLocationService();
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();

  // State
  bool _showOnMap = true;
  String _locationType = 'fixed'; // 'fixed' or 'realtime'
  String _selectedLocationType = 'workshop'; // 'workshop' or 'home'
  GeoPoint? _currentGeopoint;
  List<WorkerLocation> _userLocations = [];
  WorkerLocation? _activeLocation;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _editingLocationId; // Track if we are editing

  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadUserSettings() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    _userId = authService.currentUser?.uid;

    if (_userId == null) return;

    try {
      // Cargar configuración
      final settings = await _locationService.getLocationSettings(_userId!);
      setState(() {
        _showOnMap = settings.showOnMap;
        _locationType = settings.locationType;
      });
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Permiso de ubicación denegado.'),
                backgroundColor: Styles.errorColor,
              ),
            );
          }
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentGeopoint = GeoPoint(position.latitude, position.longitude);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ubicación actualizada por GPS'),
            backgroundColor: Styles.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo obtener la ubicación GPS.'),
            backgroundColor: Styles.errorColor,
          ),
        );
      }
    }
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
      '/freelance/map-picker',
      arguments: extras,
    );

    if (result != null) {
      setState(() {
        _currentGeopoint = GeoPoint(result.latitude, result.longitude);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ubicación actualizada'),
            backgroundColor: Styles.successColor,
          ),
        );
      }
    }
  }

  Future<void> _saveLocation() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentGeopoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona la ubicación en el mapa.'),
          backgroundColor: Styles.errorColor,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (_editingLocationId != null) {
        // Update existing location
        await _locationService.updateLocation(_editingLocationId!, {
          'type': _selectedLocationType,
          'name': _nameController.text.trim(),
          'address': _addressController.text.trim(),
          'geopoint': _currentGeopoint!,
          'description': _descriptionController.text.trim(),
        });

        // If this was the active location, update user profile too
        if (_activeLocation?.id == _editingLocationId && _userId != null) {
          // Re-activate to sync changes
          await _locationService.setActiveLocation(
            _userId!,
            _editingLocationId!,
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Ubicación actualizada!'),
              backgroundColor: Styles.successColor,
            ),
          );
        }
      } else {
        // Create new location
        final newLocation = WorkerLocation(
          id: '',
          userId: _userId!,
          type: _selectedLocationType,
          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          geopoint: _currentGeopoint!,
          description: _descriptionController.text.trim(),
          isActive: false,
          createdAt: DateTime.now(),
        );

        final newId = await _locationService.createLocation(newLocation);

        // Switch to edit mode for the newly created location
        setState(() {
          _editingLocationId = newId;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Ubicación guardada! Ahora puedes editarla.'),
              backgroundColor: Styles.successColor,
            ),
          );
        }

        // Auto-activate the new location if we are in fixed mode
        if (_locationType == 'fixed' && _userId != null) {
          debugPrint(
            '🔧 Auto-activando ubicación tipo: $_selectedLocationType',
          );
          final savedLocation = WorkerLocation(
            id: newId,
            userId: _userId!,
            type: _selectedLocationType,
            name: _nameController.text.trim(),
            address: _addressController.text.trim(),
            geopoint: _currentGeopoint!,
            description: _descriptionController.text.trim(),
            isActive: true,
            createdAt: DateTime.now(),
          );

          try {
            await _setActiveLocation(savedLocation);
            debugPrint(
              '✅ Ubicación activada correctamente: ${savedLocation.id}',
            );
          } catch (e) {
            debugPrint('❌ Error activando ubicación: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error activando ubicación: $e'),
                  backgroundColor: Styles.errorColor,
                ),
              );
            }
          }
        }
      }

      // _cancelEdit(); // REMOVED: Keep form filled
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Styles.errorColor,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _editLocation(WorkerLocation location) {
    setState(() {
      _editingLocationId = location.id;
      _selectedLocationType = location.type;
      _nameController.text = location.name;
      _addressController.text = location.address ?? '';
      _descriptionController.text = location.description ?? '';
      _currentGeopoint = location.geopoint;
      // Ensure form is visible
      _locationType = 'fixed';
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingLocationId = null;
      _nameController.clear();
      _addressController.clear();
      _descriptionController.clear();
      _currentGeopoint = null;
    });
  }

  Future<void> _deleteLocation(String locationId) async {
    try {
      await _locationService.deleteLocation(locationId);
      if (_activeLocation?.id == locationId) {
        setState(() => _activeLocation = null);
        // Update settings to remove active location
        if (_userId != null) {
          await _locationService.updateLocationSettings(
            userId: _userId!,
            showOnMap: _showOnMap,
            locationType: 'realtime', // Fallback
            activeLocationId: null,
          );
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Ubicación eliminada')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
      }
    }
  }

  Future<void> _updateSettings() async {
    if (_userId == null) return;

    try {
      await _locationService.updateLocationSettings(
        userId: _userId!,
        showOnMap: _showOnMap,
        locationType: _locationType,
        activeLocationId: _activeLocation?.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuración actualizada'),
            backgroundColor: Styles.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Styles.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _setActiveLocation(WorkerLocation location) async {
    if (_userId == null) return;

    try {
      await _locationService.setActiveLocation(_userId!, location.id);
      setState(() => _activeLocation = location);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ubicación activada'),
            backgroundColor: Styles.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Styles.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'Configuración de Ubicación',
          style: TextStyle(
            color: Styles.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Styles.textPrimary),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Styles.primaryColor),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildVisibilitySection(),
                  const SizedBox(height: 24),
                  _buildLocationTypeSection(),
                  const SizedBox(height: 24),
                  _buildLocationFormSection(),
                  const SizedBox(height: 24),
                  _buildSavedLocationsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildVisibilitySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.visibility, color: Styles.primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Visibilidad en el Mapa',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            value: _showOnMap,
            onChanged: (value) {
              setState(() => _showOnMap = value);
              _updateSettings();
            },
            title: const Text('Mostrarme en el mapa'),
            subtitle: Text(
              _showOnMap
                  ? 'Los usuarios pueden verte en el mapa'
                  : 'No apareces en el mapa',
            ),
            activeColor: Styles.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTypeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: Styles.primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Tipo de Ubicación',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          RadioListTile<String>(
            value: 'fixed',
            groupValue: _locationType,
            onChanged: _showOnMap
                ? (value) {
                    setState(() => _locationType = value!);
                    _updateSettings();
                  }
                : null,
            title: const Text('Ubicación fija (taller/domicilio)'),
            subtitle: const Text('Muestra tu taller o domicilio registrado'),
            activeColor: Styles.primaryColor,
          ),
          RadioListTile<String>(
            value: 'realtime',
            groupValue: _locationType,
            onChanged: _showOnMap
                ? (value) {
                    setState(() => _locationType = value!);
                    _updateSettings();
                  }
                : null,
            title: const Text('Ubicación en tiempo real'),
            subtitle: const Text('Muestra tu ubicación GPS actual'),
            activeColor: Styles.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationFormSection() {
    if (_locationType != 'fixed') return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.add_location, color: Styles.primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  _editingLocationId != null
                      ? 'Editar Ubicación'
                      : 'Registrar Nueva Ubicación',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Tipo', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    value: 'workshop',
                    groupValue: _selectedLocationType,
                    onChanged: (value) {
                      setState(() => _selectedLocationType = value!);
                    },
                    title: const Text('Taller'),
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    value: 'home',
                    groupValue: _selectedLocationType,
                    onChanged: (value) {
                      setState(() => _selectedLocationType = value!);
                    },
                    title: const Text('Domicilio'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre del lugar',
                hintText: 'Ej: Mi Taller de Carpintería',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v!.isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Dirección',
                hintText: 'Ej: Calle Principal #123',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                hintText: 'Referencias adicionales...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            _buildMapPreview(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _getCurrentLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Mi ubicación'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectLocationOnMap,
                    icon: const Icon(Icons.map),
                    label: const Text('Seleccionar en mapa'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Styles.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (_editingLocationId != null)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: OutlinedButton(
                        onPressed: _cancelEdit,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey,
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                  ),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Styles.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _editingLocationId != null
                                  ? 'Actualizar Ubicación'
                                  : 'Guardar Ubicación',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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

  Widget _buildMapPreview() {
    if (_currentGeopoint == null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                'Ubicación no definida',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 200,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(
              _currentGeopoint!.latitude,
              _currentGeopoint!.longitude,
            ),
            initialZoom: 15,
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
                    Icons.location_pin,
                    color: Styles.primaryColor,
                    size: 40,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedLocationsSection() {
    if (_userLocations.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bookmark, color: Styles.primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Mis Ubicaciones',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._userLocations.map((location) => _buildLocationCard(location)),
        ],
      ),
    );
  }

  Widget _buildLocationCard(WorkerLocation location) {
    final isActive = _activeLocation?.id == location.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          location.type == 'workshop' ? Icons.store : Icons.home,
          color: isActive ? Styles.primaryColor : Colors.grey,
        ),
        title: Text(
          location.name,
          style: TextStyle(
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(location.address ?? 'Sin dirección'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive)
              const Chip(
                label: Text('Activa'),
                backgroundColor: Styles.primaryColor,
                labelStyle: TextStyle(color: Colors.white, fontSize: 12),
              )
            else
              TextButton(
                onPressed: () => _setActiveLocation(location),
                child: const Text('Activar'),
              ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _editLocation(location);
                } else if (value == 'delete') {
                  _deleteLocation(location.id);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text('Editar'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Eliminar', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
