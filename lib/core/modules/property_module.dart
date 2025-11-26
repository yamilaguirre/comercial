import 'package:flutter_modular/flutter_modular.dart';
import '../layouts/property_layout.dart';
import '../../screens/property/property_list_screen.dart';
import '../../screens/property/property_favorites_screen.dart';
import '../../screens/property/property_messages_screen.dart';
import '../../screens/property/property_account_screen.dart';
import '../../screens/property/property_alerts_screen.dart';
import '../../screens/property/property_form_screen.dart';
import '../../screens/property/my_properties_screen.dart';
import '../../screens/property/property_detail_screen.dart';
import '../../screens/property/agent_management_profile_screen.dart';
import '../../screens/property/public_agent_profile_screen.dart';
import '../../screens/property/chat/property_chat_detail_screen.dart';
import '../../screens/property/collection_detail_screen.dart';
import '../../providers/mobiliaria_provider.dart';
import '../../screens/common/map_picker_screen.dart';
import '../../screens/profile/edit_profile_screen.dart';
import '../../../models/saved_collection_model.dart';

class PropertyModule extends Module {
  @override
  void binds(i) {
    i.addLazySingleton(() => MobiliariaProvider());
  }

  @override
  void routes(r) {
    r.child(
      Modular.initialRoute,
      child: (context) => const PropertyLayout(child: RouterOutlet()),
      children: [
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
        // RUTA DE EDICIÓN DE PERFIL (Se usa la pantalla de gestión como perfil de edición)
        ChildRoute(
          '/account/edit-profile', // Anidada bajo /account
          child: (context) => const AgentManagementProfileScreen(),
        ),
      ],
    );

    // 2. RUTAS SECUNDARIAS
    r.child('/new', child: (context) => const PropertyFormScreen());
    r.child('/my', child: (context) => const MyPropertiesScreen());
    r.child('/map-picker', child: (context) => const MapPickerScreen());
    r.child(
      '/edit-profile',
      child: (context) => EditProfileScreen(userData: Modular.args.data),
    );

    // RUTAS DE CHAT
    r.child(
      '/chat-detail',
      child: (context) {
        final args = Modular.args.data as Map<String, dynamic>;
        return PropertyChatDetailScreen(
          chatId: args['chatId'],
          otherUserId: args['otherUserId'],
          otherUserName: args['otherUserName'],
          otherUserPhoto: args['otherUserPhoto'],
          propertyId: args['propertyId'],
        );
      },
    );

    // RUTA DE COLECCIÓN
    r.child(
      '/collection-detail',
      child: (context) {
        final collection = Modular.args.data as SavedCollection;
        return CollectionDetailScreen(collection: collection);
      },
    );

    // Perfil de Gestión (Agente/Dueño - Ruta directa, fuera del bottom bar)
    r.child(
      '/agent-management-profile', // Nueva ruta para el perfil de gestión
      child: (context) => const AgentManagementProfileScreen(),
    );

    // Perfil Público (Cliente/Usuario - Ruta externa/detallada)
    r.child('/public-profile', child: (context) => PublicAgentProfileScreen());

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
