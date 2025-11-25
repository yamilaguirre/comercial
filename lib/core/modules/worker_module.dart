import 'package:flutter_modular/flutter_modular.dart';
import 'package:my_first_app/core/layouts/worker_layout.dart';
import 'package:my_first_app/screens/trabajador/home_work_screen.dart';
import 'package:my_first_app/screens/trabajador/worker_saved_screen.dart';
import 'package:my_first_app/screens/trabajador/worker_messages_screen.dart';
import 'package:my_first_app/screens/trabajador/worker_profile_screen.dart';
import 'package:my_first_app/screens/trabajador/worker_alerts_screen.dart';

class WorkerModule extends Module {
  @override
  void binds(i) {}

  @override
  void routes(r) {
    r.child(
      Modular.initialRoute,
      // Corregido: Solo (context)
      child: (context) => const WorkerLayout(child: RouterOutlet()),

      children: [
        // Corregido: Usar ParallelRoute.child
        ParallelRoute.child(
          '/home',
          child: (context) => const HomeWorkScreen(),
        ),
        ParallelRoute.child(
          '/favorites',
          child: (context) => const WorkerSavedScreen(),
        ),
        ParallelRoute.child(
          '/messages',
          child: (context) => const WorkerMessagesScreen(),
        ),
        ParallelRoute.child(
          '/alerts',
          child: (context) => const WorkerAlertsScreen(),
        ),
        ParallelRoute.child(
          '/account',
          child: (context) => const WorkerProfileScreen(),
        ),
      ],
    );
  }
}
