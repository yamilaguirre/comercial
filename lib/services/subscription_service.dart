import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../models/subscription_plan_model.dart';
import '../models/subscription_request_model.dart';
import 'image_service.dart';

class SubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all active subscription plans
  Future<List<SubscriptionPlan>> getActivePlans() async {
    try {
      final snapshot = await _firestore
          .collection('subscription_plans')
          .where('active', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => SubscriptionPlan.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error fetching active plans: $e');
      rethrow;
    }
  }

  // Get specific plan by ID
  Future<SubscriptionPlan?> getPlanById(String planId) async {
    try {
      final doc = await _firestore
          .collection('subscription_plans')
          .doc(planId)
          .get();

      if (!doc.exists) return null;
      return SubscriptionPlan.fromFirestore(doc);
    } catch (e) {
      print('Error fetching plan: $e');
      rethrow;
    }
  }

  // Upload payment proof to API (AWS S3)
  Future<String> uploadPaymentProof(File imageFile, String userId) async {
    try {
      final xFile = XFile(imageFile.path);
      final downloadUrl = await ImageService.uploadImageToApi(
        xFile,
        folderPath: 'subscription_receipts/$userId',
      );

      return downloadUrl;
    } catch (e) {
      print('Error uploading payment proof: $e');
      rethrow;
    }
  }

  // Create a new subscription request
  Future<String> createSubscriptionRequest({
    required String userId,
    required String planId,
    required String planName,
    required int amount,
    required String receiptUrl,
  }) async {
    try {
      final requestData = {
        'userId': userId,
        'planId': planId,
        'planName': planName,
        'amount': amount,
        'receiptUrl': receiptUrl,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore
          .collection('subscription_requests')
          .add(requestData);

      // Update user's subscription status to pending
      await _firestore.collection('users').doc(userId).update({
        'subscriptionStatus': {
          'status': 'pending',
          'planId': planId,
          'planName': planName,
          'requestId': docRef.id,
        },
      });

      return docRef.id;
    } catch (e) {
      print('Error creating subscription request: $e');
      rethrow;
    }
  }

  // Get user's latest subscription request (without requiring index)
  Future<SubscriptionRequest?> getUserSubscriptionRequest(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('subscription_requests')
          .where('userId', isEqualTo: userId)
          .get();

      if (snapshot.docs.isEmpty) return null;

      // Sort manually by createdAt descending to get latest
      final docs = snapshot.docs;
      docs.sort((a, b) {
        final aTime = (a.data()['createdAt'] as Timestamp?)?.toDate();
        final bTime = (b.data()['createdAt'] as Timestamp?)?.toDate();
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      return SubscriptionRequest.fromFirestore(docs.first);
    } catch (e) {
      print('Error fetching user subscription request: $e');
      rethrow;
    }
  }

  // Check if user has active premium in premium_users collection
  Future<Map<String, dynamic>?> getUserPremiumStatus(String userId) async {
    try {
      final doc = await _firestore
          .collection('premium_users')
          .doc(userId)
          .get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;
      // Only return if status is active
      if (data['status'] == 'active') {
        return data;
      }
      return null;
    } catch (e) {
      print('Error fetching user premium status: $e');
      rethrow;
    }
  }

  // Stream for user premium status
  Stream<Map<String, dynamic>?> getUserPremiumStatusStream(String userId) {
    return _firestore.collection('premium_users').doc(userId).snapshots().map((
      doc,
    ) {
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>;
      return data['status'] == 'active' ? data : null;
    });
  }

  // Stream for user's latest subscription request
  Stream<SubscriptionRequest?> getUserSubscriptionRequestStream(String userId) {
    return _firestore
        .collection('subscription_requests')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;

          // Sort manually by createdAt descending to get latest
          final docs = snapshot.docs.toList();
          docs.sort((a, b) {
            final aTime = (a.data()['createdAt'] as Timestamp?)?.toDate();
            final bTime = (b.data()['createdAt'] as Timestamp?)?.toDate();
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

          return SubscriptionRequest.fromFirestore(docs.first);
        });
  }

  // Get user's subscription status from users collection
  Future<Map<String, dynamic>?> getUserSubscriptionStatus(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;
      return data['subscriptionStatus'] as Map<String, dynamic>?;
    } catch (e) {
      print('Error fetching user subscription status: $e');
      rethrow;
    }
  }

  // Get the first active plan (for simplicity, assuming one active plan)
  Future<SubscriptionPlan?> getFirstActivePlan() async {
    try {
      final plans = await getActivePlans();
      return plans.isNotEmpty ? plans.first : null;
    } catch (e) {
      print('Error fetching first active plan: $e');
      rethrow;
    }
  }
}
