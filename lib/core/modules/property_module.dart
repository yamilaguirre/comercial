import 'package:flutter_modular/flutter_modular.dart';
import 'package:my_first_app/core/layouts/property_layout.dart';
// Importaciones... (las mismas que tenías)
import 'package:my_first_app/screens/property/property_list_screen.dart';
import 'package:my_first_app/screens/property/property_favorites_screen.dart';
import 'package:my_first_app/screens/property/property_messages_screen.dart';
import 'package:my_first_app/screens/property/property_account_screen.dart';
import 'package:my_first_app/screens/property/property_alerts_screen.dart';
import 'package:my_first_app/screens/property/property_form_screen.dart';
import 'package:my_first_app/screens/property/my_properties_screen.dart';
import 'package:my_first_app/screens/property/property_detail_screen.dart';

class PropertyModule extends Module {
  @override
  void binds(i) {}

  @override
  void routes(r) {
    // 1. RUTA PRINCIPAL (SHELL)
    r.child(
      Modular.initialRoute,
      // ERROR 1 SOLUCIONADO: La función solo recibe 'context'
      child: (context) => const PropertyLayout(child: RouterOutlet()),

      children: [
        // ERROR 2 SOLUCIONADO: Usar ParallelRoute.child dentro de listas
        ParallelRoute.child(
          '/home',
          child: (context) => const PropertyListScreen(),
        ),
        ParallelRoute.child(
          '/favorites',
          child: (context) => const PropertyFavoritesScreen(),
        ),
        ParallelRoute.child(
          '/messages',
          child: (context) => const PropertyMessagesScreen(),
        ),
        ParallelRoute.child(
          '/alerts',
          child: (context) => const PropertyAlertsScreen(),
        ),
        ParallelRoute.child(
          '/account',
          child: (context) => const PropertyAccountScreen(),
        ),
      ],
    );

    // 2. RUTAS SECUNDARIAS
    r.child('/new', child: (context) => const PropertyFormScreen());
    r.child('/my', child: (context) => const MyPropertiesScreen());

    // Para rutas con argumentos, usa Modular.args
    r.child(
      '/detail/:id',
      child: (context) => PropertyDetailScreen(
        propertyId: Modular.args.params['id']!,
        propertyData: Modular.args.data,
      ),
    );
  }
}
