import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../theme/theme.dart';

const String _mapboxAccessToken =
    'pk.eyJ1IjoibXVqZXJlc2Fsdm9sYW50ZSIsImEiOiJjbWFoZTR1ZzEwYXdvMmtxMHg5ZXZneXgyIn0.9aNpyQyi5wP1qKi0SjiR5Q';
const String _mapboxStyleId = 'mapbox/streets-v12';

class PropertyFormLocation extends StatelessWidget {
  final String? selectedDepartment;
  final String? selectedZone;
  final GeoPoint? currentGeopoint;
  final Map<String, List<String>> regions;
  final bool isLoadingCatalogs;
  final Function(String?) onDepartmentChanged;
  final Function(String?) onZoneChanged;
  final VoidCallback onSelectLocation;

  const PropertyFormLocation({
    super.key,
    required this.selectedDepartment,
    required this.selectedZone,
    required this.currentGeopoint,
    required this.regions,
    required this.isLoadingCatalogs,
    required this.onDepartmentChanged,
    required this.onZoneChanged,
    required this.onSelectLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- SELECTOR DE DEPARTAMENTO ---
        DropdownButtonFormField<String>(
          value: selectedDepartment,
          isExpanded:
              true, // <--- CORRECCIÓN 1: Evita que el dropdown crezca más que la pantalla
          decoration: InputDecoration(
            labelText: 'Departamento *',
            labelStyle: const TextStyle(color: Colors.black87),
            prefixIcon: Icon(Icons.map, color: Styles.primaryColor),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          items: regions.keys.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value,
                maxLines: 1, // <--- CORRECCIÓN 2: Una sola línea
                overflow: TextOverflow
                    .ellipsis, // <--- CORRECCIÓN 3: Pone "..." si no cabe
              ),
            );
          }).toList(),
          onChanged: onDepartmentChanged,
          validator: (value) =>
              value == null ? 'Selecciona un departamento' : null,
        ),

        const SizedBox(height: 16),

        // --- SELECTOR DE ZONA ---
        DropdownButtonFormField<String>(
          value: selectedZone,
          isExpanded: true, // <--- CORRECCIÓN 1 REPETIDA
          decoration: InputDecoration(
            labelText: 'Zona *',
            labelStyle: const TextStyle(color: Colors.black87),
            prefixIcon: Icon(Icons.location_city, color: Styles.primaryColor),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          items: selectedDepartment != null
              ? regions[selectedDepartment]!.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      maxLines: 1, // <--- CORRECCIÓN 2 REPETIDA
                      overflow:
                          TextOverflow.ellipsis, // <--- CORRECCIÓN 3 REPETIDA
                    ),
                  );
                }).toList()
              : [],
          onChanged: onZoneChanged,
          validator: (value) => value == null ? 'Selecciona una zona' : null,
        ),

        const SizedBox(height: 24),

        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Ubicación exacta',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              TextSpan(
                text: ' *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // --- MAPA PREVIEW ---
        GestureDetector(
          onTap: onSelectLocation,
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  if (currentGeopoint != null)
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(
                          currentGeopoint!.latitude,
                          currentGeopoint!.longitude,
                        ),
                        initialZoom: 15,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://api.mapbox.com/styles/v1/{id}/tiles/{z}/{x}/{y}?access_token={accessToken}',
                          additionalOptions: const {
                            'accessToken': _mapboxAccessToken,
                            'id': _mapboxStyleId,
                          },
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(
                                currentGeopoint!.latitude,
                                currentGeopoint!.longitude,
                              ),
                              width: 40,
                              height: 40,
                              child: Icon(
                                Icons.location_on,
                                color: Styles.primaryColor,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  else
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_location_alt_outlined,
                            size: 64,
                            color: Styles.primaryColor,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Toca para marcar en el mapa',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'La ubicación exacta ayuda a venderse más rápido',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (currentGeopoint != null)
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_location_alt,
                              size: 16,
                              color: Styles.primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Cambiar ubicación',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Styles.primaryColor,
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
    );
  }
}
