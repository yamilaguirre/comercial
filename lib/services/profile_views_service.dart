import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileViewsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Registra una vista de perfil
  static Future<void> registerProfileView({
    required String workerId,
    required String viewerId,
  }) async {
    try {
      print('🔍 [ProfileViewsService] Iniciando registro de vista');
      print('   Worker ID: $workerId');
      print('   Viewer ID: $viewerId');
      final now = DateTime.now();
      final normalizedDate = DateTime(now.year, now.month, now.day);

      // Crear una clave diaria: yyyyMMDD
      final String dateKey = '${normalizedDate.year.toString().padLeft(4, '0')}'
          '${normalizedDate.month.toString().padLeft(2, '0')}'
          '${normalizedDate.day.toString().padLeft(2, '0')}';

      // Usar ID por viewer+worker+fecha para permitir 1 vista por usuario por día
      final viewId = '${viewerId}_${workerId}_$dateKey';
      print('   View ID (daily dedup): $viewId');

      final docRef = _firestore.collection('profile_views').doc(viewId);

      // Si ya existe para este día, no crear una nueva vista
      final existing = await docRef.get();
      if (existing.exists) {
        print('ℹ️ [ProfileViewsService] Vista ya registrada hoy, omitiendo escritura');
        return;
      }

      final docData = {
        'workerId': workerId,
        'viewerId': viewerId,
        'viewedAt': FieldValue.serverTimestamp(),
        'date': Timestamp.fromDate(normalizedDate), // Fecha normalizada para queries
      };

      print('📝 [ProfileViewsService] Escribiendo en: profile_views/$viewId');
      print('   Data: $docData');

      await docRef.set(docData);

      print('✅ [ProfileViewsService] Vista registrada exitosamente en Firestore');
    } catch (e, stackTrace) {
      print('❌ [ProfileViewsService] Error registrando vista de perfil: $e');
      print('❌ StackTrace: $stackTrace');
    }
  }

  /// Obtiene el total de vistas de un trabajador
  static Future<int> getProfileViewsCount(String workerId) async {
    try {
      final viewsQuery = await _firestore
          .collection('profile_views')
          .where('workerId', isEqualTo: workerId)
          .get();

      return viewsQuery.docs.length;
    } catch (e) {
      print('Error obteniendo vistas: $e');
      return 0;
    }
  }

  /// Obtiene las vistas de los últimos N días
  static Future<int> getRecentViewsCount(
    String workerId, {
    int days = 7,
  }) async {
    try {
      final now = DateTime.now();
      final startDate = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: days));

      final viewsQuery = await _firestore
          .collection('profile_views')
          .where('workerId', isEqualTo: workerId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();

      return viewsQuery.docs.length;
    } catch (e) {
      print('Error obteniendo vistas recientes: $e');
      return 0;
    }
  }

  /// Obtiene las vistas de una fecha específica
  static Future<int> getViewsCountForDate(
    String workerId,
    DateTime date,
  ) async {
    try {
      final normalizedDate = DateTime(date.year, date.month, date.day);

      final viewsQuery = await _firestore
          .collection('profile_views')
          .where('workerId', isEqualTo: workerId)
          .where('date', isEqualTo: Timestamp.fromDate(normalizedDate))
          .get();

      return viewsQuery.docs.length;
    } catch (e) {
      print('Error obteniendo vistas del día: $e');
      return 0;
    }
  }

  /// Stream de vistas totales
  static Stream<int> getViewsCountStream(String workerId) {
    print('🔍 [ProfileViewsService] Creando stream de vistas para worker: $workerId');
    
    return _firestore
        .collection('profile_views')
        .where('workerId', isEqualTo: workerId)
        .snapshots()
        .map((snapshot) {
          final count = snapshot.docs.length;
          print('📊 [ProfileViewsService] Stream actualizado - Worker: $workerId, Count: $count');
          print('   Documentos encontrados: ${snapshot.docs.length}');
          if (snapshot.docs.isNotEmpty) {
            print('   Primeros 3 documentos:');
            for (var i = 0; i < snapshot.docs.length && i < 3; i++) {
              final doc = snapshot.docs[i];
              print('     - ${doc.id}: ${doc.data()}');
            }
          }
          return count;
        });
  }

  /// Obtiene las vistas en un rango de fechas específico
  static Stream<int> getViewsCountForRangeStream(
    String workerId,
    String period, // 'day', 'week', 'month', 'year'
  ) {
    final now = DateTime.now();
    DateTime startDate;

    switch (period) {
      case 'day':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'week':
        // Lunes de la semana actual
        startDate = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1));
        break;
      case 'month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      case 'year':
        startDate = DateTime(now.year, 1, 1);
        break;
      default:
        startDate = DateTime(now.year, now.month, now.day);
    }

    return _firestore
        .collection('profile_views')
        .where('workerId', isEqualTo: workerId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Limpia vistas antiguas (más de 90 días)
  static Future<void> cleanOldViews() async {
    try {
      final now = DateTime.now();
      final ninetyDaysAgo = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 90));

      final oldViews = await _firestore
          .collection('profile_views')
          .where('date', isLessThan: Timestamp.fromDate(ninetyDaysAgo))
          .get();

      for (var doc in oldViews.docs) {
        await doc.reference.delete();
      }

      print('🗑️ ${oldViews.docs.length} vistas antiguas eliminadas');
    } catch (e) {
      print('Error limpiando vistas antiguas: $e');
    }
  }
}
