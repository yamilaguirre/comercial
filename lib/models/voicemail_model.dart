// models/voicemail_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Voicemail {
  final String id;
  final String userId;
  final String fromUserId;
  final String fromName;
  final String? propertyId;
  final String audioUrl;
  final int durationSeconds;
  final String transcript;
  final bool isRead;
  final DateTime createdAt;

  Voicemail({
    required this.id,
    required this.userId,
    required this.fromUserId,
    required this.fromName,
    this.propertyId,
    required this.audioUrl,
    required this.durationSeconds,
    required this.transcript,
    required this.isRead,
    required this.createdAt,
  });

  factory Voicemail.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Voicemail(
      id: doc.id,
      userId: data['user_id'] ?? '',
      fromUserId: data['from_user_id'] ?? '',
      fromName: data['from_name'] ?? '',
      propertyId: data['property_id'],
      audioUrl: data['audio_url'] ?? '',
      durationSeconds: data['duration_seconds'] ?? 0,
      transcript: data['transcript'] ?? '',
      isRead: data['is_read'] ?? false,
      createdAt: (data['created_at'] as Timestamp).toDate(),
    );
  }
}