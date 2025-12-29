import 'package:cloud_firestore/cloud_firestore.dart';

class BannerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Map<String, dynamic>>> getActiveBannersStream() {
    return _firestore
        .collection('banners')
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<Map<String, dynamic>?> getActiveBanner() async {
    try {
      final snapshot = await _firestore
          .collection('banners')
          .where('active', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data();
      }
      return null;
    } catch (e) {
      print('Error fetching active banner: $e');
      return null;
    }
  }
}
