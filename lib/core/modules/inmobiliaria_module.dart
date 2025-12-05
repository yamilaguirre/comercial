import 'package:flutter_modular/flutter_modular.dart';
import '../layouts/inmobiliaria_layout.dart';
import '../../screens/inmobiliaria/inmobiliaria_home_screen.dart';
import '../../screens/inmobiliaria/inmobiliaria_properties_screen.dart';
import '../../screens/inmobiliaria/inmobiliaria_chats_screen.dart';
import '../../screens/inmobiliaria/inmobiliaria_profile_screen.dart';
import '../../screens/property/property_form_wrapper.dart';
import '../../screens/inmobiliaria/inmobiliaria_onboarding_screen.dart';
import '../../screens/inmobiliaria/inmobiliaria_subscription_payment_screen.dart';
import '../../screens/inmobiliaria/inmobiliaria_subscription_status_screen.dart';
import '../../screens/inmobiliaria/inmobiliaria_alerts_screen.dart';
import '../../screens/inmobiliaria/inmobiliaria_market_screen.dart';
import '../../providers/mobiliaria_provider.dart';

class InmobiliariaModule extends Module {
  @override
  void binds(i) {
    i.addSingleton(MobiliariaProvider.new);
  }

  @override
  void routes(r) {
    // Rutas con layout (bottom navigation)
    r.child(
      Modular.initialRoute,
      child: (context) => const InmobiliariaLayout(child: RouterOutlet()),
      transition: TransitionType.noTransition,
      children: [
        ChildRoute(
          '/home',
          child: (context) => const InmobiliariaHomeScreen(),
          transition: TransitionType.noTransition,
        ),
        ChildRoute(
          '/market',
          child: (context) => const InmobiliariaMarketScreen(),
          transition: TransitionType.noTransition,
        ),
        ChildRoute(
          '/properties',
          child: (context) => const InmobiliariaPropertiesScreen(),
          transition: TransitionType.noTransition,
        ),
        ChildRoute(
          '/chats',
          child: (context) => const InmobiliariaChatsScreen(),
          transition: TransitionType.noTransition,
        ),
        ChildRoute(
          '/profile',
          child: (context) => const InmobiliariaProfileScreen(),
          transition: TransitionType.noTransition,
        ),
      ],
    );

    // Rutas sin layout (pantalla completa)
    r.child(
      '/onboarding',
      child: (context) => const InmobiliariaOnboardingScreen(),
      transition: TransitionType.fadeIn,
    );
    r.child(
      '/subscription-payment',
      child: (context) => const InmobiliariaSubscriptionPaymentScreen(),
      transition: TransitionType.rightToLeft,
    );
    r.child(
      '/subscription-status',
      child: (context) => const InmobiliariaSubscriptionStatusScreen(),
      transition: TransitionType.rightToLeft,
    );
    r.child(
      '/new-property',
      child: (context) => const PropertyFormWrapper(),
      transition: TransitionType.rightToLeft,
    );
    r.child(
      '/alerts',
      child: (context) => const InmobiliariaAlertsScreen(),
      transition: TransitionType.rightToLeft,
    );
  }
}
