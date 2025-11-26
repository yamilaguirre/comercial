import 'package:cloud_firestore/cloud_firestore.dart';

class SavedCollection {
  final String id;
  final String userId;
  final String name;
  final List<String> propertyIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  SavedCollection({
    required this.id,
    required this.userId,
    required this.name,
    required this.propertyIds,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SavedCollection.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SavedCollection(
      id: doc.id,
      userId: data['user_id'] ?? '',
      name: data['name'] ?? '',
      propertyIds: List<String>.from(data['property_ids'] ?? []),
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'name': name,
      'property_ids': propertyIds,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  int get propertyCount => propertyIds.length;

  SavedCollection copyWith({
    String? id,
    String? userId,
    String? name,
    List<String>? propertyIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SavedCollection(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      propertyIds: propertyIds ?? this.propertyIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
