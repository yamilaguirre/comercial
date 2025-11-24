// filepath: lib/styles.dart
import 'package:flutter/material.dart';

class Styles {
  Styles._(); // no instances

  static const Color primaryColor = Color(0xFF1E3A5F);
  static const Color primaryAlt = Color(0xFF2C5F8D);

  static const List<Color> _primaryGradientColors = [primaryColor, primaryAlt];

  static LinearGradient get primaryGradient => const LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: _primaryGradientColors,
  );

  static BoxShadow elevatedShadow([double opacity = 0.25]) => BoxShadow(
    color: primaryColor.withOpacity(opacity),
    blurRadius: 12,
    offset: const Offset(0, 6),
  );

  static InputDecorationTheme inputDecorationTheme() => InputDecorationTheme(
    filled: true,
    fillColor: Colors.grey[50],
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.grey[200]!),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: primaryColor, width: 2),
    ),
  );

  static ThemeData themeData() => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: primaryColor),
    useMaterial3: true,
    inputDecorationTheme: inputDecorationTheme(),
  );
}
