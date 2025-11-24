import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';

import 'providers/auth_provider.dart';
import 'providers/mobiliaria_provider.dart';
import 'core/navigation/app_router.dart';
import 'theme/theme.dart';

void main() async {
  // Asegura que el motor de Flutter esté listo antes de llamar a código nativo (Firebase)
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa Firebase (requiere google-services.json en android/app)
  await Firebase.initializeApp();

  runApp(
    MultiProvider(
      providers: [
        // AuthProvider maneja la sesión
        ChangeNotifierProvider(create: (_) => AuthService()),
        // MobiliariaProvider maneja las propiedades
        ChangeNotifierProvider(create: (_) => MobiliariaProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    // Obtenemos la instancia de AuthService creada arriba
    final authService = context.read<AuthService>();
    // Creamos el router pasándole el servicio de autenticación para que escuche cambios
    _router = AppRouter.createRouter(authService);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Comercial',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData(),
      routerConfig: _router,
    );
  }
}
