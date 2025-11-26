import 'package:flutter_modular/flutter_modular.dart';
import 'package:my_first_app/core/layouts/worker_layout.dart';
import 'package:my_first_app/screens/trabajador/home_work_screen.dart';
import 'package:my_first_app/screens/trabajador/worker_saved_screen.dart';
import 'package:my_first_app/screens/trabajador/chat/chat_list_screen.dart';
import 'package:my_first_app/screens/trabajador/worker_profile_screen.dart';
import 'package:my_first_app/screens/trabajador/worker_alerts_screen.dart';
import 'package:my_first_app/screens/trabajador/worker_location_search_screen.dart';
import 'package:my_first_app/screens/trabajador/worker_public_profile_screen.dart';
import 'package:my_first_app/screens/trabajador/freelance_work.dart';
import 'package:my_first_app/screens/trabajador/chat/chat_detail_screen.dart';

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
          child: (context) => const WorkerSavedScreen(),
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
          child: (context) => const WorkerProfileScreen(),
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

    r.child('/edit-profile', child: (context) => const FreelanceWorkScreen());

    r.child(
      '/chat-detail',
      child: (context) => ChatDetailScreen(
        chatId: r.args.data['chatId'],
        otherUserId: r.args.data['otherUserId'],
        otherUserName: r.args.data['otherUserName'],
        otherUserPhoto: r.args.data['otherUserPhoto'],
      ),
    );
  }
}
