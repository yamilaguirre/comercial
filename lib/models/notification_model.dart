// models/notification_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  priceDropHome,
  priceDropTrend,
  propertyAvailable,
  newProperty,
  message,
  premiumPropertyPublished,
  // Notificaciones de cambios de perfil
  profilePasswordChanged,
  profilePhotoChanged,
  profileNameChanged,
  profilePhoneChanged,
  profileEmailChanged,
  // Notificaciones de trabajador
  verification;

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
      case NotificationType.premiumPropertyPublished:
        return 'Propiedad Premium';
      case NotificationType.profilePasswordChanged:
        return 'Contraseña actualizada';
      case NotificationType.profilePhotoChanged:
        return 'Foto de perfil actualizada';
      case NotificationType.profileNameChanged:
        return 'Nombre actualizado';
      case NotificationType.profilePhoneChanged:
        return 'Teléfono actualizado';
      case NotificationType.profileEmailChanged:
        return 'Email actualizado';
      case NotificationType.verification:
        return 'Verificación';
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
      case 'premium_property_published':
        return NotificationType.premiumPropertyPublished;
      case 'profile_password_changed':
        return NotificationType.profilePasswordChanged;
      case 'profile_photo_changed':
        return NotificationType.profilePhotoChanged;
      case 'profile_name_changed':
        return NotificationType.profileNameChanged;
      case 'profile_phone_changed':
        return NotificationType.profilePhoneChanged;
      case 'profile_email_changed':
        return NotificationType.profileEmailChanged;
      case 'verification':
        return NotificationType.verification;
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
      case NotificationType.premiumPropertyPublished:
        return 'premium_property_published';
      case NotificationType.profilePasswordChanged:
        return 'profile_password_changed';
      case NotificationType.profilePhotoChanged:
        return 'profile_photo_changed';
      case NotificationType.profileNameChanged:
        return 'profile_name_changed';
      case NotificationType.profilePhoneChanged:
        return 'profile_phone_changed';
      case NotificationType.profileEmailChanged:
        return 'profile_email_changed';
      case NotificationType.verification:
        return 'verification';
    }
  }
}

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final String? propertyId;
  final String? userId; // Usuario específico (para notificaciones de perfil)
  final double? oldPrice;
  final double? newPrice;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.propertyId,
    this.userId,
    this.oldPrice,
    this.newPrice,
    required this.isRead,
    required this.createdAt,
    this.metadata,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Manejo flexible de fecha (createdAt o created_at)
    DateTime? createdDate;
    if (data['created_at'] != null) {
      createdDate = (data['created_at'] as Timestamp).toDate();
    } else if (data['createdAt'] != null) {
      createdDate = (data['createdAt'] as Timestamp).toDate();
    }

    // Recopilar metadatos extra
    final Map<String, dynamic> extraMetadata = {};
    if (data['metadata'] != null) {
      extraMetadata.addAll(data['metadata'] as Map<String, dynamic>);
    }
    // Agregar campos específicos de verificación a metadata si existen
    if (data['rejectionReason'] != null)
      extraMetadata['rejectionReason'] = data['rejectionReason'];
    if (data['verificationId'] != null)
      extraMetadata['verificationId'] = data['verificationId'];
    if (data['status'] != null) extraMetadata['status'] = data['status'];

    return AppNotification(
      id: doc.id,
      type: NotificationType.fromString(data['type'] ?? 'message'),
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      propertyId: data['property_id'],
      userId: data['user_id'],
      oldPrice: data['old_price']?.toDouble(),
      newPrice: data['new_price']?.toDouble(),
      isRead: data['is_read'] ?? false, // Read directly from document
      createdAt: createdDate ?? DateTime.now(),
      metadata: extraMetadata.isNotEmpty ? extraMetadata : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.toFirestore(),
      'title': title,
      'message': message,
      'property_id': propertyId,
      'user_id': userId,
      'old_price': oldPrice,
      'new_price': newPrice,
      'created_at': Timestamp.fromDate(createdAt),
      'is_read': isRead,
      'metadata': metadata,
    };
  }

  AppNotification copyWith({
    String? id,
    NotificationType? type,
    String? title,
    String? message,
    String? propertyId,
    String? userId,
    double? oldPrice,
    double? newPrice,
    bool? isRead,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      propertyId: propertyId ?? this.propertyId,
      userId: userId ?? this.userId,
      oldPrice: oldPrice ?? this.oldPrice,
      newPrice: newPrice ?? this.newPrice,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }
}
