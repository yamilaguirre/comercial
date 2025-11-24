import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../screens/onboarding/onboarding_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/auth/register_form_screen.dart';
import '../../screens/auth/role_selection_screen.dart';
import '../../screens/property_list_screen.dart';
import '../../screens/work_list_screen.dart';
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

      redirect: (BuildContext context, GoRouterState state) {
        if (!authProvider.isAuthReady) return null;

        final isLoggedIn = authProvider.isAuthenticated;
        final location = state.uri.toString();

        final publicRoutes = ['/', '/login', '/register', '/register-form'];
        final isPublicRoute = publicRoutes.any(
          (route) => location == route || location.startsWith('$route?'),
        );

        if (!isLoggedIn) {
          if (!isPublicRoute) return '/';
          return null;
        }

        if (isLoggedIn) {
          if (isPublicRoute) {
            return '/select-role';
          }
          return null;
        }

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

        // SELECCIÓN DE ROL
        GoRoute(
          path: '/select-role',
          name: 'select-role',
          builder: (context, state) => const RoleSelectionScreen(),
        ),

        // PRIVADAS
        ShellRoute(
          navigatorKey: _shellNavigatorKey,
          builder: (context, state, child) => MainLayout(child: child),
          routes: [
            GoRoute(
              path: '/property-home',
              name: 'property-home',
              builder: (context, state) => const PropertyListScreen(),
            ),
            GoRoute(
              path: '/work-home',
              name: 'work-home',
              builder: (context, state) => const WorkListScreen(),
            ),
            GoRoute(
              path: '/favorites',
              name: 'favorites',
              builder: (context, state) {
                final uid = authProvider.currentUser?.uid ?? '';
                return FavoritesScreen(userId: uid);
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
              builder: (context, state) => const AccountScreen(),
            ),
          ],
        ),

        // Rutas secundarias
        GoRoute(
          path: '/edit-profile',
          name: 'edit-profile',
          builder: (context, state) {
            final userData = state.extra as Map<String, dynamic>?;
            return EditProfileScreen(userData: userData);
          },
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
            if (property == null) return const MyPropertiesScreen();
            return PropertyFormScreen(propertyToEdit: property);
          },
        ),
        GoRoute(
          path: '/property-detail/:id',
          name: 'property-detail',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            final property = state.extra as Property?;
            return PropertyDetailScreen(propertyId: id, propertyData: property);
          },
        ),

        // --- CORRECCIÓN AQUÍ ---
        GoRoute(
          path: '/map-picker',
          name: 'map-picker',
          builder: (context, state) {
            // Usamos dynamic para evitar errores de casteo si viene como Map<dynamic, dynamic>
            final extras = state.extra as Map<String, dynamic>?;

            // Convertimos explícitamente a double, manejando nulls y tipos numéricos (int/double)
            final lat = (extras?['lat'] as num?)?.toDouble();
            final lng = (extras?['lng'] as num?)?.toDouble();

            return MapPickerScreen(initialLat: lat, initialLng: lng);
          },
        ),
      ],
    );
  }
}

extension AppRouterExtension on BuildContext {
  void goToHome() => go('/property-home');
  void goToLogin() => go('/login');
  void goToRegister() => go('/register');
}
