import 'package:go_router/go_router.dart';
import '../../../screens/trabajador/home_work_screen.dart';
import '../../../screens/trabajador/freelance_work.dart';
import '../../../screens/trabajador/worker_saved_screen.dart';
import '../../../screens/trabajador/worker_profile_screen.dart';

List<RouteBase> getWorkerRoutes() {
  return [
    GoRoute(
      path: '/work-home',
      name: 'work-home',
      builder: (context, state) => const HomeWorkScreen(),
    ),
    GoRoute(
      path: '/freelance-work',
      name: 'freelance-work',
      builder: (context, state) => const FreelanceWorkScreen(),
    ),
    GoRoute(
      path: '/worker-saved',
      name: 'worker-saved',
      builder: (context, state) => const WorkerSavedScreen(),
    ),
    GoRoute(
      path: '/worker-profile',
      name: 'worker-profile',
      builder: (context, state) => const WorkerProfileScreen(),
    ),
  ];
}
