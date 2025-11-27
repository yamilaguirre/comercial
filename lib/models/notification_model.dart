// models/notification_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  priceDropHome,
  priceDropTrend,
  propertyAvailable,
  newProperty,
  message;

  String get displayName {
    switch (this) {
      case NotificationType.priceDropHome:
        return 'Rebaja de precio';
      case NotificationType.priceDropTrend:
        return 'Rebaja de precio';
      case NotificationType.propertyAvailable:
        return 'Propiedad guardada disponible';
      case NotificationType.newProperty:
        return 'Nueva propiedad';
      case NotificationType.message:
        return 'Mensaje';
    }
  }

  static NotificationType fromString(String value) {
    switch (value) {
      case 'price_drop_home':
        return NotificationType.priceDropHome;
      case 'price_drop_trend':
        return NotificationType.priceDropTrend;
      case 'property_available':
        return NotificationType.propertyAvailable;
      case 'new_property':
        return NotificationType.newProperty;
      case 'message':
        return NotificationType.message;
      default:
        return NotificationType.message;
    }
  }

  String toFirestore() {
    switch (this) {
      case NotificationType.priceDropHome:
        return 'price_drop_home';
      case NotificationType.priceDropTrend:
        return 'price_drop_trend';
      case NotificationType.propertyAvailable:
        return 'property_available';
      case NotificationType.newProperty:
        return 'new_property';
      case NotificationType.message:
        return 'message';
    }
  }
}

class AppNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String message;
  final String? propertyId;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.propertyId,
    required this.isRead,
    required this.createdAt,
    this.metadata,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      userId: data['user_id'] ?? '',
      type: NotificationType.fromString(data['type'] ?? 'message'),
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      propertyId: data['property_id'],
      isRead: data['is_read'] ?? false,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'type': type.toFirestore(),
      'title': title,
      'message': message,
      'property_id': propertyId,
      'is_read': isRead,
      'created_at': Timestamp.fromDate(createdAt),
      'metadata': metadata,
    };
  }

  AppNotification copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    String? title,
    String? message,
    String? propertyId,
    bool? isRead,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      propertyId: propertyId ?? this.propertyId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }
}
