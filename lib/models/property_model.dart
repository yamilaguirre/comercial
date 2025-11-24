// models/property_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Property {
  final String id;
  final String ownerId;
  final String title;
  final String description;
  final String transactionType;
  final String propertyType;
  final double price;
  final String currency;
  final int areaSqm;
  final int rooms;
  final int bathrooms;
  final String department;
  final String zoneKey;
  final Map<String, dynamic> amenities;
  final GeoPoint geopoint;
  final bool isActive;
  final DateTime createdAt;

  Property({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.transactionType,
    required this.propertyType,
    required this.price,
    required this.currency,
    required this.areaSqm,
    required this.rooms,
    required this.bathrooms,
    required this.department,
    required this.zoneKey,
    required this.amenities,
    required this.geopoint,
    required this.isActive,
    required this.createdAt,
  });

  factory Property.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Property(
      id: doc.id,
      ownerId: data['owner_id'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      transactionType: data['transaction_type'] ?? '',
      propertyType: data['property_type'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      currency: data['currency'] ?? 'USD',
      areaSqm: data['area_sqm'] ?? 0,
      rooms: data['rooms'] ?? 0,
      bathrooms: data['bathrooms'] ?? 0,
      department: data['department'] ?? '',
      zoneKey: data['zone_key'] ?? '',
      amenities: data['amenities'] ?? {},
      geopoint: data['geopoint'] ?? const GeoPoint(0, 0),
      isActive: data['is_active'] ?? true,
      createdAt: (data['created_at'] as Timestamp).toDate(),
    );
  }
}