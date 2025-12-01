import 'package:flutter_modular/flutter_modular.dart';
import 'package:my_first_app/core/layouts/freelance_layout.dart';
import 'package:my_first_app/screens/trabajador/worker_profile_screen.dart';
import 'package:my_first_app/screens/trabajador/chat/chat_list_screen.dart';
import 'package:my_first_app/screens/trabajador/chat/chat_detail_screen.dart';
import 'package:my_first_app/screens/trabajador/worker_location_config_screen.dart';
import 'package:my_first_app/screens/common/map_picker_screen.dart';

class FreelanceModule extends Module {
  @override
  void binds(i) {}

  @override
  void routes(r) {
    r.child(
      Modular.initialRoute,
      child: (context) => const FreelanceLayout(child: RouterOutlet()),
      children: [
        ParallelRoute.child(
          'home',
          child: (context) => const WorkerProfileScreen(),
        ),
        ParallelRoute.child(
          'messages',
          child: (context) => const ChatListScreen(),
        ),
        ParallelRoute.child(
          'location-config',
          child: (context) => const WorkerLocationConfigScreen(),
        ),
      ],
    );

    // Rutas fuera del layout principal (pantallas completas)
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
      '/map-picker',
      child: (context) => MapPickerScreen(
        initialLat: r.args.data?['lat'],
        initialLng: r.args.data?['lng'],
      ),
    );
  }
}
