import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/mobiliaria_provider.dart';
import 'property_form_screen.dart';

class PropertyFormWrapper extends StatelessWidget {
  const PropertyFormWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Modular.get<AuthService>();
    final user = authService.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => MobiliariaProvider(),
      child: const PropertyFormScreen(),
    );
  }
}
