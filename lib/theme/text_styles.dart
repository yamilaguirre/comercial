/// Estilos de texto reutilizables para la aplicación
///
/// Define todos los TextStyle utilizados en la app para mantener
/// consistencia tipográfica en toda la interfaz.
library;

import 'package:flutter/material.dart';
import 'styles.dart';

/// Clase estática que contiene los estilos de texto predefinidos
class TextStyles {
  TextStyles._(); // Constructor privado

  // ==================== TÍTULOS ====================

  /// Estilo para títulos principales (H1)
  static const TextStyle title = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: Styles.primaryColor,
    letterSpacing: 0.5,
    height: 1.2,
  );

  /// Estilo para títulos secundarios (H2)
  static const TextStyle titleSecondary = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Styles.textPrimary,
    letterSpacing: 0.3,
    height: 1.3,
  );

  /// Estilo para títulos terciarios (H3)
  static const TextStyle titleTertiary = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Styles.textPrimary,
    letterSpacing: 0.2,
  );

  // ==================== SUBTÍTULOS Y CUERPO ====================

  /// Estilo para subtítulos y texto secundario
  static const TextStyle subtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: Styles.textSecondary,
    height: 1.5,
  );

  /// Estilo para texto de cuerpo normal
  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: Styles.textPrimary,
    height: 1.5,
  );

  /// Estilo para texto pequeño (caption)
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: Styles.textSecondary,
    height: 1.4,
  );

  // ==================== BOTONES Y ENLACES ====================

  /// Estilo para texto de botones
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    letterSpacing: 0.5,
  );

  /// Estilo para enlaces y texto interactivo
  static const TextStyle link = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Styles.primaryColor,
    decoration: TextDecoration.none,
  );

  // ==================== ETIQUETAS Y BADGES ====================

  /// Estilo para etiquetas y badges
  static const TextStyle badge = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 0.3,
  );

  /// Estilo para precio destacado
  static const TextStyle price = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: Colors.green,
    letterSpacing: 0.2,
  );
}
