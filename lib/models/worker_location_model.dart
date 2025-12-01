// models/worker_location_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class WorkerLocation {
  final String id;
  final String userId;
  final String type; // 'workshop' or 'home'
  final String name;
  final String? address;
  final GeoPoint geopoint;
  final String? description;
  final bool isActive;
  final DateTime createdAt;

  WorkerLocation({
    required this.id,
    required this.userId,
    required this.type,
    required this.name,
    this.address,
    required this.geopoint,
    this.description,
    required this.isActive,
    required this.createdAt,
  });

  factory WorkerLocation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WorkerLocation(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: data['type'] ?? 'home',
      name: data['name'] ?? '',
      address: data['address'],
      geopoint: data['geopoint'] ?? const GeoPoint(0, 0),
      description: data['description'],
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'type': type,
      'name': name,
      'address': address,
      'geopoint': geopoint,
      'description': description,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class LocationSettings {
  final bool showOnMap;
  final String locationType; // 'fixed' or 'realtime'
  final String? activeLocationId;

  LocationSettings({
    required this.showOnMap,
    required this.locationType,
    this.activeLocationId,
  });

  factory LocationSettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return LocationSettings(
        showOnMap: true,
        locationType: 'fixed',
        activeLocationId: null,
      );
    }
    return LocationSettings(
      showOnMap: data['showOnMap'] ?? true,
      locationType: data['locationType'] ?? 'fixed',
      activeLocationId: data['activeLocationId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'showOnMap': showOnMap,
      'locationType': locationType,
      'activeLocationId': activeLocationId,
    };
  }
}
