import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../screens/onboarding/onboarding_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/auth/register_form_screen.dart';
import '../../screens/auth/role_selection_screen.dart';
import '../../screens/property_list_screen.dart';
import '../../screens/trabajador/home_work_screen.dart';
import '../../screens/trabajador/freelance_work.dart';
import '../../screens/trabajador/worker_profile_screen.dart';
import '../../screens/trabajador/worker_saved_screen.dart';
import '../../screens/favorites_screen.dart';
import '../../screens/alerts_screen.dart';
import '../../screens/messages_screen.dart';
import '../../screens/account_screen.dart';
import '../../screens/profile/edit_profile_screen.dart';
import '../../screens/property/my_properties_screen.dart';
import '../../screens/property/property_form_screen.dart';
import '../../screens/property_detail_screen.dart';
import '../../screens/map_picker_screen.dart';
import '../../providers/auth_provider.dart';
import '../layouts/main_layout.dart';
import '../../models/property.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter createRouter(AuthService authProvider) {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/',
      debugLogDiagnostics: true,
      refreshListenable: authProvider,

      redirect: (BuildContext context, GoRouterState state) async {
        final isLoggedIn = authProvider.isAuthenticated;
        final location = state.fullPath;

        // Rutas públicas
        final publicRoutes = ['/', '/login', '/register', '/register-form'];

        // Si NO está logueado
        if (!isLoggedIn) {
          if (publicRoutes.contains(location)) return null;
          return '/';
        }

        // Si SÍ está logueado
        final user = authProvider.currentUser;
        if (user == null) return '/login';

        // Obtener rol del usuario desde Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final userRole = userDoc.data()?['role'] ?? 'cliente';

        // Si el usuario está en /select-role, permitir que permanezca ahí
        if (location == '/select-role') return null;

        // Solo usuarios con role='cliente' deben ir a seleccionar rol
        if (userRole == 'cliente') {
          return '/select-role';
        }

        // Usuario CON rol definido (trabajo o inmobiliaria)
        // Determinar home según rol
        final expectedHome = userRole == 'trabajo' ? '/work-home' : '/home';

        // Rutas protegidas que no necesitan redirección
        final protectedRoutes = [
          '/home',
          '/work-home',
          '/favorites',
          '/messages',
          '/alerts',
          '/account',
          '/edit-profile',
          '/freelance-work',
          '/property/new',
          '/property/my',
          '/map-picker',
        ];

        // Si está en una ruta que comienza con /property-detail o /property/edit
        if (location != null &&
            (location.startsWith('/property-detail/') ||
                location.startsWith('/property/edit/'))) {
          return null;
        }

        // Si está en el home incorrecto, redirigir al correcto
        if (location == '/home' || location == '/work-home') {
          if (location != expectedHome) {
            return expectedHome;
          }
        }

        // Si no está en ninguna ruta protegida, redirigir al home correcto
        if (location != null &&
            !protectedRoutes.any((route) => location.startsWith(route))) {
          return expectedHome;
        }

        // Permitir cualquier otra ruta protegida
        return null;
      },

      routes: [
        // PÚBLICAS
        GoRoute(
          path: '/',
          name: 'onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          name: 'register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/register-form',
          name: 'register-form',
          builder: (context, state) {
            final type = state.uri.queryParameters['type'] ?? 'cliente';
            return RegisterFormScreen(userType: type);
          },
        ),
        // RUTA DE SELECCIÓN DE ROL (Punto de entrada para usuarios logueados)
        GoRoute(
          path: '/select-role',
          name: 'select-role',
          builder: (context, state) => const RoleSelectionScreen(),
        ),

        // PRIVADAS (SHELL - NAVEGACIÓN PRINCIPAL)
        ShellRoute(
          navigatorKey: _shellNavigatorKey,
          builder: (context, state, child) => MainLayout(child: child),
          routes: [
            // HOME INMOBILIARIA/CLIENTE (Lista de propiedades)
            GoRoute(
              path: '/home',
              name: 'home',
              builder: (context, state) => const PropertyListScreen(),
            ),
            // HOME TRABAJADOR (Lista de servicios/trabajos)
            GoRoute(
              path: '/work-home',
              name: 'work-home',
              builder: (context, state) => const HomeWorkScreen(),
            ),

            GoRoute(
              path: '/favorites',
              name: 'favorites',
              builder: (context, state) {
                // Detectar el rol del usuario y mostrar la pantalla apropiada
                final uid = authProvider.currentUser?.uid;
                if (uid == null) {
                  return FavoritesScreen(userId: '');
                }

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final userData =
                        snapshot.data!.data() as Map<String, dynamic>?;
                    final userRole = userData?['role'] ?? 'cliente';

                    // Si es trabajador, mostrar WorkerSavedScreen
                    if (userRole == 'trabajo') {
                      return const WorkerSavedScreen();
                    }

                    // Para otros roles, mostrar FavoritesScreen (propiedades guardadas)
                    return FavoritesScreen(userId: uid);
                  },
                );
              },
            ),
            GoRoute(
              path: '/messages',
              name: 'messages',
              builder: (context, state) => const MessagesScreen(),
            ),
            GoRoute(
              path: '/alerts',
              name: 'alerts',
              builder: (context, state) => const AlertsScreen(),
            ),
            GoRoute(
              path: '/account',
              name: 'account',
              builder: (context, state) {
                // Detectar el rol del usuario y mostrar la pantalla apropiada
                final uid = authProvider.currentUser?.uid;
                if (uid == null) {
                  return const AccountScreen();
                }

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final userData =
                        snapshot.data!.data() as Map<String, dynamic>?;
                    final userRole = userData?['role'] ?? 'cliente';

                    // Si es trabajador, mostrar WorkerProfileScreen
                    if (userRole == 'trabajo') {
                      return const WorkerProfileScreen();
                    }

                    // Para otros roles, mostrar AccountScreen
                    return const AccountScreen();
                  },
                );
              },
            ),
          ],
        ),

        // Rutas secundarias (FUERA DEL SHELL)
        GoRoute(
          path: '/edit-profile',
          name: 'edit-profile',
          builder: (context, state) {
            final userData = state.extra as Map<String, dynamic>?;
            return EditProfileScreen(userData: userData);
          },
        ),

        // Ruta para crear perfil de trabajador
        GoRoute(
          path: '/freelance-work',
          name: 'freelance-work',
          builder: (context, state) => const FreelanceWorkScreen(),
        ),

        GoRoute(
          path: '/property/new',
          name: 'property-new',
          builder: (context, state) => const PropertyFormScreen(),
        ),

        GoRoute(
          path: '/property/my',
          name: 'property-my',
          builder: (context, state) => const MyPropertiesScreen(),
        ),

        GoRoute(
          path: '/property/edit/:id',
          name: 'property-edit',
          builder: (context, state) {
            final property = state.extra as Property?;
            if (property == null) {
              return const MyPropertiesScreen();
            }
            return PropertyFormScreen(propertyToEdit: property);
          },
        ),

        // DETALLE DE PROPIEDAD
        GoRoute(
          path: '/property-detail/:id',
          name: 'property-detail',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            final property = state.extra as Property?;
            return PropertyDetailScreen(propertyId: id, propertyData: property);
          },
        ),

        GoRoute(
          path: '/map-picker',
          name: 'map-picker',
          builder: (context, state) {
            final extras = state.extra as Map<String, double>?;
            return MapPickerScreen(
              initialLat: extras?['lat'],
              initialLng: extras?['lng'],
            );
          },
        ),
      ],
    );
  }
}

extension AppRouterExtension on BuildContext {
  Future<void> goToHome() async {
    // Obtener el rol del usuario para navegar al home correcto
    final authService = Provider.of<AuthService>(this, listen: false);
    final user = authService.currentUser;

    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final userRole = userDoc.data()?['role'] ?? 'cliente';

        if (userRole == 'trabajo') {
          go('/work-home');
        } else {
          go('/home');
        }
      } catch (e) {
        // En caso de error, ir al home por defecto
        go('/home');
      }
    } else {
      go('/home');
    }
  }

  void goToLogin() => go('/login');
  void goToRegister() => go('/register');
}
