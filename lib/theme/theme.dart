/// Punto de entrada único para todos los archivos de tema
///
/// Este archivo "barrel" exporta todos los módulos de tema,
/// permitiendo importar todo el sistema de diseño con una sola línea:
/// ```dart
/// import 'package:my_first_app/theme/theme.dart';
/// ```
library;

// Exportar todos los archivos de tema
export 'app_theme.dart';
export 'component_themes.dart';
export 'styles.dart';
export 'text_styles.dart';
