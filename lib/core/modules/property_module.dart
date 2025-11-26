import 'package:flutter_modular/flutter_modular.dart';
import 'package:my_first_app/core/layouts/property_layout.dart';
import 'package:flutter/material.dart';
// Importaciones de pantallas
import 'package:my_first_app/screens/property/property_list_screen.dart';
import 'package:my_first_app/screens/property/property_favorites_screen.dart';
import 'package:my_first_app/screens/property/property_messages_screen.dart';
import 'package:my_first_app/screens/property/property_account_screen.dart';
import 'package:my_first_app/screens/property/property_alerts_screen.dart';
import 'package:my_first_app/screens/property/property_form_screen.dart';
import 'package:my_first_app/screens/property/my_properties_screen.dart';
import 'package:my_first_app/screens/property/property_detail_screen.dart';
// Importo esta pantalla para completar el módulo (aunque no la hayamos visto)
/* import 'package:my_first_app/screens/property/chat_detail_screen.dart';
import 'package:my_first_app/screens/property/property_search_screen.dart';
import 'package:my_first_app/screens/property/property_edit_screen.dart';
 */

class PropertyModule extends Module {
  @override
  void binds(i) {}

  @override
  void routes(r) {
    // 1. RUTA PRINCIPAL (SHELL) - Contiene el layout de navegación inferior.
    // Modular 6.x asume que la primera ruta hija será la que se cargue por defecto
    // si se navega a la raíz del Shell (/property/).
    r.child(
      Modular.initialRoute, // Path: '/' del módulo (ej: /property/)
      child: (context) => const PropertyLayout(child: RouterOutlet()),

      children: [
        // RUTA HIJA POR DEFECTO DEL SHELL (Explorar)
        // Usamos 'home' en lugar de Modular.initialRoute para evitar conflicto
        ParallelRoute.child(
          'home', // Path relativo: 'home'
          child: (context) => const PropertyListScreen(),
        ),

        // RUTAS SECUNDARIAS DEL LAYOUT (BOTTOM NAVIGATION BAR)
        ParallelRoute.child(
          'favorites', // -> /property/favorites
          child: (context) => const PropertyFavoritesScreen(),
        ),
        ParallelRoute.child(
          'messages', // -> /property/messages
          child: (context) => const PropertyMessagesScreen(),
        ),
        ParallelRoute.child(
          'alerts', // -> /property/alerts
          child: (context) => const PropertyAlertsScreen(),
        ),
        ParallelRoute.child(
          'account', // -> /property/account
          child: (context) => const PropertyAccountScreen(),
        ),
      ],
    );

    // 2. RUTAS FUERA DEL LAYOUT PRINCIPAL (Basado en tu estructura de WorkerModule)

    r.child('/new', child: (context) => const PropertyFormScreen());

    r.child('/my', child: (context) => const MyPropertiesScreen());

    /*     r.child(
      '/location-search',
      child: (context) => const PropertySearchScreen(),
    ); */

    r.child(
      '/detail/:id',
      child: (context) => PropertyDetailScreen(
        propertyId: Modular.args.params['id']!,
        propertyData: Modular.args.data,
      ),
    );

    /*     // Asumiendo que el chat también tiene una vista detallada
    r.child(
      '/chat-detail/:chatId',
      child: (context) => ChatDetailScreen(
        chatId: r.args.params['chatId']!,
        // Usamos Modular.args para pasar el resto de los datos necesarios
        otherUserId: r.args.data['otherUserId'],
        otherUserName: r.args.data['otherUserName'],
      ),
    );
    
    r.child(
      '/edit-profile', // Asumiendo que tienes una pantalla de edición de perfil para inmobiliarias
      child: (context) => const PropertyEditScreen(),
    ); */
  }
}
