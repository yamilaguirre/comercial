import 'package:cloud_firestore/cloud_firestore.dart';

class Property {
  final String id;
  final String name;
  final String price;
  final String location;
  final String imageUrl;
  final double rating;
  final String description;
  final String type; // Tipo de transacción (sale, rent, etc.)

  // --- CAMPO NUEVO ---
  // Este es el campo que te faltaba. Guarda el valor crudo (ej: 'local_comercial')
  // para que los dropdowns funcionen correctamente al editar.
  final String propertyTypeRaw;

  final List<String> amenities;
  final int bedrooms;
  final int bathrooms;
  final double area;
  final GeoPoint? geopoint;
  final String ownerId;
  final List<String> imageUrls;

  // Campos opcionales para edición precisa
  final String? department;
  final String? zone;

  Property({
    required this.id,
    required this.name,
    required this.price,
    required this.location,
    required this.imageUrl,
    required this.rating,
    required this.description,
    required this.type,
    required this.propertyTypeRaw, // Requerido ahora
    this.amenities = const [],
    this.bedrooms = 0,
    this.bathrooms = 0,
    this.area = 0,
    this.geopoint,
    this.ownerId = '',
    this.imageUrls = const [],
    this.department,
    this.zone,
  });

  factory Property.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    List<String> activeAmenities = [];
    if (data['amenities'] is Map) {
      (data['amenities'] as Map).forEach((key, value) {
        if (value == true) activeAmenities.add(key);
      });
    }

    List<String> urls = [];
    if (data['imageUrls'] is List) {
      urls = List<String>.from(
        data['imageUrls'],
      ).where((url) => url.isNotEmpty).toList();
    }

    final firstImageUrl = urls.isNotEmpty
        ? urls.first
        : 'https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=400&h=300&fit=crop';

    return Property(
      id: doc.id,
      name: data['title'] ?? 'Sin título',
      price: '${data['currency'] ?? ''} ${data['price']?.toString() ?? '0'}',
      location:
          data['zone_key'] ?? data['department'] ?? 'Ubicación desconocida',
      imageUrl: firstImageUrl,
      rating: data['rating']?.toDouble() ?? 0.0,
      description: data['description'] ?? 'Sin descripción.',
      type: data['transaction_type'] ?? 'sale',

      // --- ASIGNACIÓN DEL NUEVO CAMPO ---
      // Si no existe en la base de datos (propiedades viejas), asumimos 'casa' por defecto
      propertyTypeRaw: data['property_type'] ?? 'casa',

      amenities: activeAmenities,
      bedrooms: data['rooms'] ?? 0,
      bathrooms: data['bathrooms'] ?? 0,
      area: (data['area_sqm'] ?? 0).toDouble(),
      geopoint: _parseGeoPoint(data['geopoint']),
      ownerId: data['owner_id'] ?? '',
      imageUrls: urls,
      department: data['department'],
      zone: data['zone_key'],
    );
  }

  // Helper para parsear GeoPoint de forma segura
  static GeoPoint? _parseGeoPoint(dynamic geopointData) {
    if (geopointData == null) return null;

    if (geopointData is GeoPoint) {
      return geopointData;
    }

    if (geopointData is Map) {
      final lat = geopointData['latitude'] ?? geopointData['_latitude'];
      final lng = geopointData['longitude'] ?? geopointData['_longitude'];
      if (lat != null && lng != null) {
        return GeoPoint(lat.toDouble(), lng.toDouble());
      }
    }

    return null;
  }

  // Getters para acceder a latitud y longitud desde geopoint
  double get latitude => geopoint?.latitude ?? 0.0;
  double get longitude => geopoint?.longitude ?? 0.0;
}
