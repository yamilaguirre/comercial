import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionRequest {
  final String id;
  final String userId;
  final String planId;
  final String planName;
  final int amount;
  final String receiptUrl;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime? createdAt;
  final DateTime? processedAt;
  final String? processedBy;
  final String? rejectionReason;

  SubscriptionRequest({
    required this.id,
    required this.userId,
    required this.planId,
    required this.planName,
    required this.amount,
    required this.receiptUrl,
    required this.status,
    this.createdAt,
    this.processedAt,
    this.processedBy,
    this.rejectionReason,
  });

  factory SubscriptionRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SubscriptionRequest(
      id: doc.id,
      userId: data['userId'] ?? '',
      planId: data['planId'] ?? '',
      planName: data['planName'] ?? '',
      amount: data['amount'] ?? 0,
      receiptUrl: data['receiptUrl'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      processedAt: (data['processedAt'] as Timestamp?)?.toDate(),
      processedBy: data['processedBy'],
      rejectionReason: data['rejectionReason'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'planId': planId,
      'planName': planName,
      'amount': amount,
      'receiptUrl': receiptUrl,
      'status': status,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      if (processedAt != null) 'processedAt': Timestamp.fromDate(processedAt!),
      if (processedBy != null) 'processedBy': processedBy,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
    };
  }
}
