import 'package:flutter_modular/flutter_modular.dart';
import 'package:chaski_comercial/providers/auth_provider.dart';
import 'package:chaski_comercial/core/modules/auth_module.dart';
import 'package:chaski_comercial/core/modules/property_module.dart';
import 'package:chaski_comercial/core/modules/worker_module.dart';
import 'package:chaski_comercial/core/modules/freelance_module.dart';
import 'package:chaski_comercial/core/modules/inmobiliaria_module.dart';
import 'package:chaski_comercial/core/guards/auth_guard.dart';

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
