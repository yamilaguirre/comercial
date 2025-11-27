import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

/// Utilidades para geometría y cálculos con mapas
class MapGeometryUtils {
  /// Verifica si un punto está dentro de un polígono usando el algoritmo Ray Casting
  static bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;

    bool inside = false;
    final x = point.latitude;
    final y = point.longitude;

    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].latitude;
      final yi = polygon[i].longitude;
      final xj = polygon[j].latitude;
      final yj = polygon[j].longitude;

      final intersect =
          ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi);

      if (intersect) inside = !inside;
    }

    return inside;
  }

  /// Calcula el centroide (centro geométrico) de un polígono
  static LatLng calculateCentroid(List<LatLng> points) {
    if (points.isEmpty) {
      return const LatLng(0, 0);
    }

    double sumLat = 0;
    double sumLng = 0;

    for (var point in points) {
      sumLat += point.latitude;
      sumLng += point.longitude;
    }

    return LatLng(sumLat / points.length, sumLng / points.length);
  }

  /// Calcula la distancia entre dos puntos usando la fórmula de Haversine (en metros)
  static double calculateDistance(LatLng point1, LatLng point2) {
    const earthRadius = 6371000; // Radio de la Tierra en metros

    final lat1 = point1.latitude * math.pi / 180;
    final lat2 = point2.latitude * math.pi / 180;
    final deltaLat = (point2.latitude - point1.latitude) * math.pi / 180;
    final deltaLng = (point2.longitude - point1.longitude) * math.pi / 180;

    final a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLng / 2) *
            math.sin(deltaLng / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  /// Calcula el área aproximada de un polígono (en km²)
  static double calculatePolygonArea(List<LatLng> polygon) {
    if (polygon.length < 3) return 0;

    double area = 0;
    final int n = polygon.length;

    for (int i = 0; i < n; i++) {
      final j = (i + 1) % n;
      final lat1 = polygon[i].latitude;
      final lng1 = polygon[i].longitude;
      final lat2 = polygon[j].latitude;
      final lng2 = polygon[j].longitude;

      area += lng1 * lat2;
      area -= lng2 * lat1;
    }

    area = area.abs() / 2;

    // Convertir de grados² a km² (aproximación para áreas pequeñas)
    const kmPerDegree = 111.0;
    return area * kmPerDegree * kmPerDegree;
  }
}
