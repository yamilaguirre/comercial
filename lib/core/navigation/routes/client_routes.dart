import 'package:go_router/go_router.dart';
import '../../../screens/property_list_screen.dart';
import '../../../screens/property/property_form_screen.dart';
import '../../../screens/property/my_properties_screen.dart';
import '../../../screens/property_detail_screen.dart';
import '../../../models/property.dart';

List<RouteBase> getClientRoutes() {
  return [
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => const PropertyListScreen(),
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
    GoRoute(
      path: '/property-detail/:id',
      name: 'property-detail',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        final property = state.extra as Property?;
        return PropertyDetailScreen(propertyId: id, propertyData: property);
      },
    ),
  ];
}
