// models/saved_list_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class SavedList {
  final String id;
  final String userId;
  final String listName;
  final List<String> propertyIds;
  final DateTime createdAt;

  SavedList({
    required this.id,
    required this.userId,
    required this.listName,
    required this.propertyIds,
    required this.createdAt,
  });

  factory SavedList.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SavedList(
      id: doc.id,
      userId: data['user_id'] ?? '',
      listName: data['list_name'] ?? '',
      propertyIds: List<String>.from(data['property_ids'] ?? []),
      createdAt: (data['created_at'] as Timestamp).toDate(),
    );
  }
}
