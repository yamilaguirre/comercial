import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;

/// Punto con coordenadas de pantalla y geográficas
class DrawingPoint {
  final Offset screenPoint;
  final LatLng geoPoint;

  DrawingPoint(this.screenPoint, this.geoPoint);
}

/// Widget que permite dibujar polígonos en el mapa con visualización en tiempo real
class MapDrawingDetector extends StatefulWidget {
  /// Se llama cuando se completa un dibujo válido
  final Function(List<LatLng> polygon)? onPolygonDrawn;

  /// Se llama cuando el usuario empieza a dibujar
  final Function()? onDrawingStart;

  /// Color de la línea de dibujo
  final Color drawingColor;

  /// Ancho de la línea de dibujo
  final double strokeWidth;

  /// Si el modo de dibujo está activo
  final bool isEnabled;

  /// Controlador del mapa
  final flutter_map.MapController mapController;

  /// Número mínimo de puntos para formar un polígono
  final int minPoints;

  const MapDrawingDetector({
    super.key,
    this.onPolygonDrawn,
    this.onDrawingStart,
    this.drawingColor = const Color(0xFF0033CC),
    this.strokeWidth = 4.0,
    required this.isEnabled,
    required this.mapController,
    this.minPoints = 3,
  });

  @override
  State<MapDrawingDetector> createState() => _MapDrawingDetectorState();
}

class _MapDrawingDetectorState extends State<MapDrawingDetector> {
  List<DrawingPoint> _drawnPoints = [];
  bool _isDrawing = false;

  @override
  void didUpdateWidget(MapDrawingDetector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isEnabled && oldWidget.isEnabled) {
      _clearDrawing();
    }
  }

  void _onPanStart(DragStartDetails details) {
    if (!widget.isEnabled) return;

    setState(() {
      _isDrawing = true;
      _drawnPoints.clear();
    });

    widget.onDrawingStart?.call();
    _addPoint(details.localPosition);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!widget.isEnabled || !_isDrawing) return;
    _addPoint(details.localPosition);
  }

  void _onPanEnd(DragEndDetails details) {
    if (!widget.isEnabled || !_isDrawing) return;

    _isDrawing = false;

    if (_drawnPoints.length >= widget.minPoints) {
      final polygon = _drawnPoints.map((p) => p.geoPoint).toList();
      widget.onPolygonDrawn?.call(polygon);
    }

    _clearDrawing();
  }

  void _addPoint(Offset screenPosition) {
    final geoPoint = _screenToLatLng(screenPosition);
    if (geoPoint == null) return;

    // Sampling: solo agregar puntos a cierta distancia
    if (_drawnPoints.isNotEmpty) {
      final distance =
          (screenPosition - _drawnPoints.last.screenPoint).distance;
      if (distance < 3.0) return;
    }

    setState(() {
      _drawnPoints.add(DrawingPoint(screenPosition, geoPoint));
    });
  }

  LatLng? _screenToLatLng(Offset screenPoint) {
    try {
      final camera = widget.mapController.camera;
      return camera.pointToLatLng(math.Point(screenPoint.dx, screenPoint.dy));
    } catch (e) {
      return null;
    }
  }

  void _clearDrawing() {
    setState(() {
      _drawnPoints.clear();
      _isDrawing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEnabled) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // Detector de gestos
        Positioned.fill(
          child: GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: Container(color: Colors.transparent),
          ),
        ),

        // Visualizador de la línea EN TIEMPO REAL usando coordenadas de pantalla
        if (_drawnPoints.isNotEmpty)
          Positioned.fill(
            child: CustomPaint(
              key: ValueKey(
                _drawnPoints.length,
              ), // Fuerza rebuild en cada punto nuevo
              painter: _DrawingPainter(
                points: _drawnPoints,
                color: widget.drawingColor,
                strokeWidth: widget.strokeWidth,
              ),
              willChange: true, // Indica que va a cambiar frecuentemente
            ),
          ),
      ],
    );
  }
}

/// Painter que dibuja usando coordenadas de pantalla directamente
class _DrawingPainter extends CustomPainter {
  final List<DrawingPoint> points;
  final Color color;
  final double strokeWidth;

  _DrawingPainter({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = ui.Path();

    // Usar coordenadas de pantalla directamente
    path.moveTo(points.first.screenPoint.dx, points.first.screenPoint.dy);

    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].screenPoint.dx, points[i].screenPoint.dy);
    }

    // Dibujar la línea
    canvas.drawPath(path, linePaint);

    // Dibujar puntos para visibilidad
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (var point in points) {
      canvas.drawCircle(point.screenPoint, strokeWidth * 1.5, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) {
    // Siempre repintar para asegurar visualización en tiempo real
    return true;
  }
}
