import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionPlan {
  final String id;
  final String name;
  final int price;
  final String currency;
  final String duration; // 'monthly', 'yearly', etc.
  final String qrCodeUrl;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.currency,
    required this.duration,
    required this.qrCodeUrl,
    required this.active,
    this.createdAt,
    this.updatedAt,
  });

  factory SubscriptionPlan.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SubscriptionPlan(
      id: doc.id,
      name: data['name'] ?? '',
      price: data['price'] ?? 0,
      currency: data['currency'] ?? 'BOB',
      duration: data['duration'] ?? 'monthly',
      qrCodeUrl: data['qrCodeUrl'] ?? '',
      active: data['active'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'currency': currency,
      'duration': duration,
      'qrCodeUrl': qrCodeUrl,
      'active': active,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
