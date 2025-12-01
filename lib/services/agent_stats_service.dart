import 'package:cloud_firestore/cloud_firestore.dart';

class AgentStatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Obtener estadísticas del agente
  Future<Map<String, dynamic>> getAgentStats(String userId) async {
    try {
      // Obtener propiedades del usuario
      final propertiesSnapshot = await _firestore
          .collection('properties')
          .where('owner_id', isEqualTo: userId)
          .get();

      int totalProperties = propertiesSnapshot.docs.length;
      int activeProperties = 0;
      int totalViews = 0;
      int totalInquiries = 0;
      int totalFavorites = 0;

      for (var doc in propertiesSnapshot.docs) {
        final data = doc.data();
        if (data['is_active'] == true) activeProperties++;
        totalViews += (data['views'] ?? 0) as int;
        totalInquiries += (data['inquiries'] ?? 0) as int;
        totalFavorites += (data['favorites'] ?? 0) as int;
      }

      return {
        'totalProperties': totalProperties,
        'activeProperties': activeProperties,
        'pausedProperties': totalProperties - activeProperties,
        'totalViews': totalViews,
        'totalInquiries': totalInquiries,
        'totalFavorites': totalFavorites,
      };
    } catch (e) {
      print('Error getting agent stats: $e');
      return {
        'totalProperties': 0,
        'activeProperties': 0,
        'pausedProperties': 0,
        'totalViews': 0,
        'totalInquiries': 0,
        'totalFavorites': 0,
      };
    }
  }
}
