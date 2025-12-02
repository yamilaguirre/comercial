import 'package:flutter_modular/flutter_modular.dart';
import 'package:my_first_app/providers/auth_provider.dart';
import 'package:my_first_app/core/modules/auth_module.dart';
import 'package:my_first_app/core/modules/property_module.dart';
import 'package:my_first_app/core/modules/worker_module.dart';
import 'package:my_first_app/core/modules/freelance_module.dart';
import 'package:my_first_app/core/modules/inmobiliaria_module.dart';
import 'package:my_first_app/core/guards/auth_guard.dart';

class AppModule extends Module {
  @override
  void binds(i) {
    i.addSingleton(() => AuthService());
  }

  @override
  void routes(r) {
    r.module(Modular.initialRoute, module: AuthModule());

    r.module(
      '/property',
      module: PropertyModule(),
      guards: [AuthGuard(requiredRole: 'inmobiliaria')],
    );

    r.module('/worker', module: WorkerModule());

    r.module('/freelance', module: FreelanceModule());

    r.module('/inmobiliaria', module: InmobiliariaModule());
  }
}
