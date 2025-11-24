/// Temas y decoraciones para componentes específicos
///
/// Contiene las configuraciones de tema para Cards, Containers
/// y otros elementos de UI reutilizables.
library;

import 'package:flutter/material.dart';
import 'styles.dart';

/// Clase estática con temas de componentes personalizados
class ComponentThemes {
  ComponentThemes._(); // Constructor privado

  // ==================== CARD THEME ====================

  /// Tema para Cards principales
  static CardTheme cardTheme = CardTheme(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Styles.radiusXLarge),
    ),
    elevation: 20,
    shadowColor: Colors.black.withOpacity(0.25),
    color: Colors.white,
    margin: const EdgeInsets.symmetric(
      vertical: Styles.spacingSmall,
      horizontal: 0,
    ),
  );

  /// Tema para Cards secundarios (menos elevación)
  static CardTheme cardThemeSecondary = CardTheme(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Styles.radiusMedium),
    ),
    elevation: 4,
    shadowColor: Colors.black.withOpacity(0.1),
    color: Colors.white,
    margin: const EdgeInsets.symmetric(
      vertical: Styles.spacingSmall,
      horizontal: 0,
    ),
  );

  // ==================== DECORACIONES DE CONTENEDORES ====================

  /// Decoración para caja de información (azul/púrpura suave)
  static BoxDecoration infoBoxDecoration() => BoxDecoration(
    color: Styles.primaryAlt.withOpacity(0.08),
    borderRadius: BorderRadius.circular(Styles.radiusMedium),
    border: Border.all(color: Styles.primaryAlt.withOpacity(0.2), width: 1),
  );

  /// Decoración para caja de error (rojo suave)
  static BoxDecoration errorBoxDecoration() => BoxDecoration(
    color: Colors.red[50],
    borderRadius: BorderRadius.circular(Styles.radiusMedium),
    border: Border.all(color: Colors.red[200]!),
  );

  /// Decoración para caja de éxito (verde suave)
  static BoxDecoration successBoxDecoration() => BoxDecoration(
    color: Colors.green[50],
    borderRadius: BorderRadius.circular(Styles.radiusMedium),
    border: Border.all(color: Colors.green[200]!),
  );

  /// Decoración para caja de advertencia (naranja suave)
  static BoxDecoration warningBoxDecoration() => BoxDecoration(
    color: Colors.orange[50],
    borderRadius: BorderRadius.circular(Styles.radiusMedium),
    border: Border.all(color: Colors.orange[200]!),
  );

  // ==================== BADGES Y CHIPS ====================

  /// Decoración para badge destacado
  static BoxDecoration badgeDecoration({Color? color}) => BoxDecoration(
    color: color ?? Styles.primaryAlt,
    borderRadius: BorderRadius.circular(Styles.radiusMedium),
    boxShadow: [
      BoxShadow(
        color: (color ?? Styles.primaryAlt).withOpacity(0.3),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ],
  );

  // ==================== DIVISORES ====================

  /// Border divisor sutil
  static Border bottomBorder() =>
      const Border(bottom: BorderSide(color: Styles.borderColor, width: 1));

  /// BoxDecoration con sombra suave para contenedores
  static BoxDecoration containerWithShadow() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(Styles.radiusMedium),
    boxShadow: [Styles.softShadow()],
  );
}
