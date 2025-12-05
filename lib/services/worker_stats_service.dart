import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WorkerStatsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Guarda un snapshot de las estadísticas del día
  static Future<void> saveStatsSnapshot(String userId) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Obtener estadísticas actuales
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();

      if (userData == null) return;

      // Contar vistas desde profile_views
      final viewsQuery = await _firestore
          .collection('profile_views')
          .where('workerId', isEqualTo: userId)
          .get();
      final views = viewsQuery.docs.length;

      // Contar contactos (chats)
      final chatsQuery = await _firestore
          .collection('chats')
          .where('user_ids', arrayContains: userId)
          .get();
      final contactsCount = chatsQuery.docs.length;

      // Contar reviews
      final reviewsData = await calculateWorkerRating(userId);
      final reviewsCount = reviewsData['reviews'] as int;

      // Guardar snapshot del día
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('stats_snapshots')
          .doc(today.millisecondsSinceEpoch.toString())
          .set({
            'date': Timestamp.fromDate(today),
            'views': views,
            'contacts': contactsCount,
            'reviews': reviewsCount,
            'timestamp': FieldValue.serverTimestamp(),
          });

      // Limpiar snapshots antiguos (más de 30 días)
      final thirtyDaysAgo = today.subtract(const Duration(days: 30));
      final oldSnapshots = await _firestore
          .collection('users')
          .doc(userId)
          .collection('stats_snapshots')
          .where('date', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      for (var doc in oldSnapshots.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Error saving stats snapshot: $e');
    }
  }

  /// Calcula el rating del trabajador desde la colección feedback
  static Future<Map<String, dynamic>> calculateWorkerRating(
    String workerId,
  ) async {
    try {
      // Obtener todos los feedbacks para este trabajador
      final feedbackQuery = await _firestore
          .collection('feedback')
          .where('workerId', isEqualTo: workerId)
          .get();

      double totalRating = 0;
      int reviewCount = 0;

      for (var feedbackDoc in feedbackQuery.docs) {
        final feedbackData = feedbackDoc.data();
        final rating = feedbackData['rating'] as num?;

        if (rating != null && rating > 0) {
          totalRating += rating.toDouble();
          reviewCount++;
        }
      }

      return {
        'rating': reviewCount > 0 ? totalRating / reviewCount : 0.0,
        'reviews': reviewCount,
      };
    } catch (e) {
      print('Error calculating rating: $e');
      return {'rating': 0.0, 'reviews': 0};
    }
  }

  /// Calcula las tendencias (cambios vs semana anterior, hoy, etc.)
  static Future<Map<String, dynamic>> calculateTrends(String userId) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final sevenDaysAgo = today.subtract(const Duration(days: 7));

      // Obtener estadísticas actuales
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();

      if (userData == null) {
        return _getDefaultTrends();
      }

      // Contar vistas desde profile_views
      final viewsQuery = await _firestore
          .collection('profile_views')
          .where('workerId', isEqualTo: userId)
          .get();
      final currentViews = viewsQuery.docs.length;

      // Contar contactos actuales
      final chatsQuery = await _firestore
          .collection('chats')
          .where('user_ids', arrayContains: userId)
          .get();
      final currentContacts = chatsQuery.docs.length;

      // Contar reviews actuales
      final reviewsData = await calculateWorkerRating(userId);
      final currentReviews = reviewsData['reviews'] as int;

      // Obtener snapshots históricos
      final snapshots = await _firestore
          .collection('users')
          .doc(userId)
          .collection('stats_snapshots')
          .orderBy('date', descending: true)
          .limit(14)
          .get();

      if (snapshots.docs.isEmpty) {
        return _getDefaultTrends();
      }

      // Buscar snapshot de ayer para calcular "nuevos hoy"
      int yesterdayContacts = currentContacts;

      for (var doc in snapshots.docs) {
        final data = doc.data();
        final date = (data['date'] as Timestamp).toDate();
        final normalizedDate = DateTime(date.year, date.month, date.day);

        if (normalizedDate.isAtSameMomentAs(yesterday)) {
          yesterdayContacts =
              (data['contacts'] as num?)?.toInt() ?? currentContacts;
          break;
        }
      }

      // Buscar snapshot de hace 7 días para calcular "vs semana anterior"
      int sevenDaysAgoViews = currentViews;
      int sevenDaysAgoReviews = currentReviews;

      for (var doc in snapshots.docs) {
        final data = doc.data();
        final date = (data['date'] as Timestamp).toDate();
        final normalizedDate = DateTime(date.year, date.month, date.day);

        if (normalizedDate.isAtSameMomentAs(sevenDaysAgo) ||
            normalizedDate.isBefore(sevenDaysAgo)) {
          sevenDaysAgoViews = (data['views'] as num?)?.toInt() ?? currentViews;
          sevenDaysAgoReviews =
              (data['reviews'] as num?)?.toInt() ?? currentReviews;
          break;
        }
      }

      // Calcular tendencias de visitas (% vs semana anterior)
      String viewsTrend;
      Color viewsTrendColor;
      if (sevenDaysAgoViews > 0) {
        final viewsChange =
            ((currentViews - sevenDaysAgoViews) / sevenDaysAgoViews * 100)
                .round();
        if (viewsChange > 0) {
          viewsTrend = '+$viewsChange% vs semana anterior';
          viewsTrendColor = const Color(0xFF4CAF50); // Green
        } else if (viewsChange < 0) {
          viewsTrend = '$viewsChange% vs semana anterior';
          viewsTrendColor = const Color(0xFFF44336); // Red
        } else {
          viewsTrend = 'Sin cambios esta semana';
          viewsTrendColor = const Color(0xFF9E9E9E); // Grey
        }
      } else {
        viewsTrend = 'Datos insuficientes';
        viewsTrendColor = const Color(0xFF9E9E9E);
      }

      // Calcular tendencias de contactos (nuevos hoy)
      String contactsTrend;
      Color contactsTrendColor;
      final newContactsToday = currentContacts - yesterdayContacts;
      if (newContactsToday > 0) {
        contactsTrend = '+$newContactsToday nuevos hoy';
        contactsTrendColor = const Color(0xFF4CAF50);
      } else if (newContactsToday < 0) {
        contactsTrend = 'Sin nuevos contactos hoy';
        contactsTrendColor = const Color(0xFF9E9E9E);
      } else {
        contactsTrend = 'Sin nuevos contactos hoy';
        contactsTrendColor = const Color(0xFF9E9E9E);
      }

      // Calcular tendencias de reviews (esta semana)
      String reviewsTrend;
      Color reviewsTrendColor;
      final newReviewsThisWeek = currentReviews - sevenDaysAgoReviews;
      if (newReviewsThisWeek > 0) {
        reviewsTrend = '+$newReviewsThisWeek esta semana';
        reviewsTrendColor = const Color(0xFF4CAF50);
      } else if (newReviewsThisWeek < 0) {
        reviewsTrend = 'Sin nuevas recomendaciones';
        reviewsTrendColor = const Color(0xFF9E9E9E);
      } else {
        reviewsTrend = 'Sin nuevas recomendaciones';
        reviewsTrendColor = const Color(0xFF9E9E9E);
      }

      return {
        'viewsTrend': viewsTrend,
        'viewsTrendColor': viewsTrendColor,
        'contactsTrend': contactsTrend,
        'contactsTrendColor': contactsTrendColor,
        'reviewsTrend': reviewsTrend,
        'reviewsTrendColor': reviewsTrendColor,
      };
    } catch (e) {
      print('Error calculating trends: $e');
      return _getDefaultTrends();
    }
  }

  static Map<String, dynamic> _getDefaultTrends() {
    return {
      'viewsTrend': 'Datos insuficientes',
      'viewsTrendColor': const Color(0xFF9E9E9E),
      'contactsTrend': 'Sin datos',
      'contactsTrendColor': const Color(0xFF9E9E9E),
      'reviewsTrend': 'Sin datos',
      'reviewsTrendColor': const Color(0xFF9E9E9E),
    };
  }

  /// Stream para las tendencias en tiempo real
  static Stream<Map<String, dynamic>> getTrendsStream(String userId) async* {
    // Emitir tendencias actuales
    yield await calculateTrends(userId);

    // Actualizar cada vez que cambien los snapshots
    await for (var _
        in _firestore
            .collection('users')
            .doc(userId)
            .collection('stats_snapshots')
            .snapshots()) {
      yield await calculateTrends(userId);
    }
  }
}
