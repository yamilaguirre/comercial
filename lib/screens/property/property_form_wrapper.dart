import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../theme/theme.dart';
import 'property_form_screen.dart';
import 'verification_required_screen.dart';

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

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Styles.primaryColor),
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const VerificationRequiredScreen();
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        final verificationStatus = userData?['verificationStatus'];

        // Si está verificado, mostrar el formulario
        if (verificationStatus == 'verified') {
          return const PropertyFormScreen();
        }

        // Si no está verificado, mostrar pantalla de verificación requerida
        return const VerificationRequiredScreen();
      },
    );
  }
}
