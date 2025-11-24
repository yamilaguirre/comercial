/// Configuración del tema principal de la aplicación
///
/// Este archivo centraliza la configuración del ThemeData que se aplica
/// globalmente a toda la aplicación a través de MaterialApp.
library;

import 'package:flutter/material.dart';
import 'styles.dart';
import 'text_styles.dart';

/// Clase que gestiona el tema de la aplicación
class AppTheme {
  AppTheme._(); // Constructor privado

  /// TextTheme personalizado con los estilos definidos
  static final TextTheme _textTheme = TextTheme(
    headlineLarge: TextStyles.title,
    headlineMedium: TextStyles.titleSecondary,
    headlineSmall: TextStyles.titleTertiary,
    titleLarge: TextStyles.title,
    titleMedium: TextStyles.titleSecondary,
    titleSmall: TextStyles.titleTertiary,
    bodyLarge: TextStyles.body,
    bodyMedium: TextStyles.subtitle,
    bodySmall: TextStyles.caption,
    labelLarge: TextStyles.button,
    labelMedium: TextStyles.link,
    labelSmall: TextStyles.badge,
  );

  /// ThemeData principal de la aplicación
  ///
  /// Configura colores, tipografía y temas de componentes
  /// que se aplicarán globalmente.
  static ThemeData themeData() => ThemeData(
    // Esquema de colores basado en el color primario
    colorScheme: ColorScheme.fromSeed(
      seedColor: Styles.primaryColor,
      primary: Styles.primaryColor,
      secondary: Styles.primaryAlt,
      tertiary: Styles.accentColor,
      surface: Colors.white,
      background: Styles.neutralLight,
    ),

    // Tipografía personalizada
    textTheme: _textTheme,

    // Habilitar Material Design 3
    useMaterial3: true,

    // Tema de decoración de inputs
    inputDecorationTheme: Styles.inputDecorationTheme(),

    // Tema de botones elevados
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Styles.primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Styles.radiusLarge),
        ),
        padding: const EdgeInsets.symmetric(
          vertical: Styles.spacingMedium,
          horizontal: Styles.spacingLarge,
        ),
        elevation: 4,
        textStyle: TextStyles.button,
      ),
    ),

    // Tema de AppBar
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: Styles.primaryColor,
      foregroundColor: Colors.white,
      titleTextStyle: TextStyles.titleTertiary.copyWith(
        color: Colors.white,
        fontSize: 20,
      ),
    ),

    // Tema de botones de texto
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Styles.primaryColor,
        textStyle: TextStyles.link,
      ),
    ),

    // Tema de botones con borde
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Styles.primaryColor,
        side: const BorderSide(color: Styles.primaryColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Styles.radiusLarge),
        ),
        padding: const EdgeInsets.symmetric(
          vertical: Styles.spacingMedium,
          horizontal: Styles.spacingLarge,
        ),
      ),
    ),

    // Tema de FloatingActionButton
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Styles.accentColor,
      foregroundColor: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Styles.radiusLarge),
      ),
    ),

    // Tema de diálogos (DialogThemeData)
    dialogTheme: const DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Styles.radiusLarge)),
      ),
      elevation: 24,
    ),

    // Tema de bottom sheets
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Styles.radiusXLarge),
        ),
      ),
      elevation: 16,
    ),

    // Tema de bottom navigation bar (moderno y limpio)
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: Styles.primaryColor,
      unselectedItemColor: Styles.textSecondary,
      selectedLabelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      showSelectedLabels: true,
      showUnselectedLabels: true,
    ),
  );
}
