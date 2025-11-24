/// Estilos y constantes de diseño de la aplicación
///
/// Esta clase contiene todos los colores, gradientes, sombras y decoraciones
/// utilizados en la aplicación para mantener consistencia visual.
library;

import 'package:flutter/material.dart';

/// Clase estática que contiene todas las constantes de estilo
class Styles {
  Styles._(); // Constructor privado para prevenir instanciación

  // ==================== COLORES ====================

  /// Color primario de la marca (Azul Comercial)
  static const Color primaryColor = Color(0xFF001BB7);

  /// Color alternativo/secundario de la marca (Azul más oscuro)
  static const Color primaryAlt = Color(0xFF001494);

  /// Color de acento (Naranja) - usado para CTAs y alertas importantes
  static const Color accentColor = Color(0xFFFF6B35);

  /// Colores neutros para fondos y bordes
  static const Color neutralLight = Color(0xFFF5F5F5);
  static const Color neutralMedium = Color(0xFFE0E0E0);
  static const Color borderColor = Color(0xFFE9ECEF);
  static const Color backgroundLight = Color(0xFFF5F5F5);

  /// Color de texto por defecto
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF616161);
  static const Color textDisabled = Color(0xFF9E9E9E);
  static const Color textTertiary = Color(0xFF9E9E9E);

  /// Colores de estado
  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color errorColor = Color(0xFFF44336);
  static const Color infoColor = Color(0xFF9C27B0);

  // ==================== GRADIENTES ====================

  /// Gradiente primario de la marca (opcional - ahora preferimos color sólido)
  static LinearGradient get primaryGradient => const LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      primaryColor,
      primaryColor, // Mismo color para simular color sólido
    ],
  );

  /// Color sólido de fondo para pantallas de login/splash (sin degradado)
  static BoxDecoration backgroundDecoration() => BoxDecoration(
    color: primaryColor, // Color sólido azul
  );

  // ==================== SOMBRAS ====================

  /// Sombra elevada con el color primario
  static BoxShadow elevatedShadow([double opacity = 0.25]) => BoxShadow(
    color: primaryColor.withOpacity(opacity),
    blurRadius: 12,
    offset: const Offset(0, 6),
  );

  /// Sombra suave para cards y contenedores
  static BoxShadow softShadow() => BoxShadow(
    color: Colors.black.withOpacity(0.05),
    blurRadius: 8,
    offset: const Offset(0, 2),
  );

  // ==================== BORDES REDONDEADOS ====================

  /// Radio de borde estándar para elementos pequeños
  static const double radiusSmall = 8.0;

  /// Radio de borde para elementos medianos (botones, inputs)
  static const double radiusMedium = 12.0;

  /// Radio de borde para cards y contenedores grandes
  static const double radiusLarge = 16.0;

  /// Radio de borde extra grande para modals y cards destacados
  static const double radiusXLarge = 24.0;

  // ==================== ESPACIADO ====================

  /// Padding/margin pequeño
  static const double spacingXSmall = 4.0;
  static const double spacingSmall = 8.0;

  /// Padding/margin mediano
  static const double spacingMedium = 16.0;

  /// Padding/margin grande
  static const double spacingLarge = 24.0;
  static const double spacingXLarge = 32.0;

  // ==================== TEMAS DE COMPONENTES ====================

  /// Tema para los campos de texto (TextFormField)
  static InputDecorationTheme inputDecorationTheme() => InputDecorationTheme(
    filled: true,
    fillColor: neutralLight,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusLarge),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusLarge),
      borderSide: const BorderSide(color: neutralMedium),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusLarge),
      borderSide: const BorderSide(color: primaryColor, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusLarge),
      borderSide: const BorderSide(color: Colors.red, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusLarge),
      borderSide: const BorderSide(color: Colors.red, width: 2),
    ),
  );
}
