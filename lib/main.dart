// filepath: lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart'; // Reemplaza go_router y provider
import 'package:provider/provider.dart';
import 'package:my_first_app/providers/auth_provider.dart';
import 'package:firebase_core/firebase_core.dart';

// Importaciones específicas del proyecto
import 'core/modules/app_module.dart';
import 'theme/theme.dart';
import 'firebase_options.dart'; // Para una correcta inicialización de Firebase

void main() async {
  // Asegura que el motor de Flutter esté listo antes de llamar a código nativo (Firebase)
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa Firebase usando las opciones por defecto para la plataforma actual
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // === CAMBIO CLAVE: Usa ModularApp como widget raíz ===
  // ModularApp inyecta el módulo principal (AppModule) y gestiona el ruteo y las dependencias.
  runApp(
    ModularApp(
      module: AppModule(),
      child: const MyAppWidget(), // El widget que contiene MaterialApp.router
    ),
  );
}

// Widget principal que usa la configuración de Modular
class MyAppWidget extends StatelessWidget {
  const MyAppWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: Modular.get<AuthService>(),
      child: MaterialApp.router(
        title: 'Comercial',
        debugShowCheckedModeBanner: false,
        // Obtenemos el tema globalmente
        theme: AppTheme.themeData(),
        // La configuración de rutas (routerConfig) se obtiene directamente de Modular
        routerConfig: Modular.routerConfig,
      ),
    );
  }
}
