import 'package:flutter_modular/flutter_modular.dart';
import 'package:chaski_comercial/core/layouts/worker_layout.dart';
import 'package:chaski_comercial/screens/trabajador/home_work_screen.dart';
import 'package:chaski_comercial/screens/trabajador/chat/chat_list_screen.dart';
import 'package:chaski_comercial/screens/trabajador/worker_profile_screen.dart';
import 'package:chaski_comercial/screens/trabajador/worker_alerts_screen.dart';
import 'package:chaski_comercial/screens/trabajador/worker_location_search_screen.dart';
import 'package:chaski_comercial/screens/trabajador/worker_public_profile_screen.dart';
import 'package:chaski_comercial/screens/trabajador/freelance_work.dart';
import 'package:chaski_comercial/screens/trabajador/chat/chat_detail_screen.dart';
import 'package:chaski_comercial/screens/trabajador/worker_account_screen.dart';
import 'package:chaski_comercial/screens/trabajador/worker_favorites_screen.dart';
import 'package:chaski_comercial/screens/trabajador/worker_collection_detail_screen.dart';
import 'package:chaski_comercial/screens/trabajador/edit_account_screen.dart';
import 'package:chaski_comercial/screens/trabajador/worker_verification_screen.dart';
import 'package:chaski_comercial/screens/trabajador/subscription_qr_payment_screen.dart';
import 'package:chaski_comercial/screens/trabajador/subscription_status_screen.dart';

class WorkerModule extends Module {
  @override
  void binds(i) {}

  @override
  void routes(r) {
    r.child(
      Modular.initialRoute,
      child: (context) => const WorkerLayout(child: RouterOutlet()),
      children: [
        ParallelRoute.child(
          'home-worker',
          child: (context) => const HomeWorkScreen(),
        ),
        ParallelRoute.child(
          'favorites',
          child: (context) => const WorkerFavoritesScreen(),
        ),
        ParallelRoute.child(
          'messages',
          child: (context) => const ChatListScreen(),
        ),
        ParallelRoute.child(
          'alerts',
          child: (context) => const WorkerAlertsScreen(),
        ),
        ParallelRoute.child(
          'profile',
          child: (context) => const WorkerProfileScreen(),
        ),
        ParallelRoute.child(
          'account',
          child: (context) => const WorkerAccountScreen(),
        ),
      ],
    );

    // Rutas fuera del layout principal (pantallas completas)
    r.child(
      '/location-search',
      child: (context) => const WorkerLocationSearchScreen(),
    );

    r.child(
      '/public-profile',
      child: (context) => WorkerPublicProfileScreen(worker: r.args.data),
    );

    r.child(
      '/collection-detail',
      child: (context) => WorkerCollectionDetailScreen(collection: r.args.data),
    );

    r.child('/edit-profile', child: (context) => const FreelanceWorkScreen());

    r.child('/edit-account', child: (context) => const EditAccountScreen());

    r.child(
      '/chat-detail',
      child: (context) => ChatDetailScreen(
        chatId: r.args.data['chatId'],
        otherUserId: r.args.data['otherUserId'],
        otherUserName: r.args.data['otherUserName'],
        otherUserPhoto: r.args.data['otherUserPhoto'],
      ),
    );

    r.child(
      '/verification',
      child: (context) => const WorkerVerificationScreen(),
    );

    r.child(
      '/subscription-payment',
      child: (context) => const SubscriptionQRPaymentScreen(),
    );

    r.child(
      '/subscription-status',
      child: (context) => const SubscriptionStatusScreen(),
    );
  }
}
