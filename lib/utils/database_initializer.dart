// utils/database_initializer.dart
import '../services/data_seeder.dart';

class DatabaseInitializer {
  static bool _isInitialized = false;

  /// Ejecuta el seeder solo una vez para poblar la base de datos
  /// Usar solo en desarrollo
  static Future<String> initializeDatabase() async {
    if (_isInitialized) {
      return 'Base de datos ya inicializada';
    }

    try {
      final result = await seedDatabase();
      _isInitialized = true;
      return result;
    } catch (e) {
      return 'Error inicializando base de datos: $e';
    }
  }

  /// Verifica si la base de datos ya fue inicializada
  static bool get isInitialized => _isInitialized;

  /// Resetea el estado (solo para testing)
  static void reset() {
    _isInitialized = false;
  }
}
