import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import 'package:chaski_comercial/services/ad_service.dart';
import '../../theme/theme.dart';
import '../property/components/account_menu_section.dart';
import 'premium_subscription_modal.dart';

import '../../services/premium_notification_service.dart';

class WorkerAccountScreen extends StatefulWidget {
  const WorkerAccountScreen({super.key});

  @override
  State<WorkerAccountScreen> createState() => _WorkerAccountScreenState();
}

class _WorkerAccountScreenState extends State<WorkerAccountScreen> {
  bool showPremiumModal = false;
  bool _hasTriggeredPremiumAction = false;

  // --- FUNCIÓN: ABRIR WHATSAPP DE SOPORTE ---
  Future<void> _openSupportWhatsApp() async {
    try {
      // Obtener datos de soporte desde Firestore
      final supportDoc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('support')
          .get();

      if (!supportDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo obtener información de soporte'),
            ),
          );
        }
        return;
      }

      final supportData = supportDoc.data() as Map<String, dynamic>;
      final whatsappNumber = supportData['whatsappNumber'] as String?;
      final supportName = supportData['supportName'] as String?;

      if (whatsappNumber == null || whatsappNumber.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Número de WhatsApp no disponible')),
          );
        }
        return;
      }

      // Limpiar el número de espacios y caracteres especiales
      final cleanNumber = whatsappNumber.replaceAll(RegExp(r'[^\d]'), '');

      // Crear mensaje predeterminado
      final message = Uri.encodeComponent(
        'Hola, necesito ayuda con la aplicación Comercial. ¿Podrían asistirme?',
      );

      // URL de WhatsApp
      final whatsappUrl = 'https://wa.me/$cleanNumber?text=$message';

      final uri = Uri.parse(whatsappUrl);

      await AdService.instance.showInterstitialThen(() async {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No se pudo abrir WhatsApp')),
            );
          }
        }
      });
    } catch (e) {
      print('Error al abrir WhatsApp de soporte: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // --- FUNCIÓN: CAMBIAR DE MÓDULO (REDIRECCIÓN A INMOBILIARIA) ---
  void _changeModule() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    if (user == null) {
      Modular.to.navigate('/login');
      return;
    }

    try {
      // Cambiar el rol del usuario a 'inmobiliaria' antes de navegar
      await authService.updateUserRole('inmobiliaria');
      // Navegar al módulo de property (pantalla principal)
      Modular.to.navigate('/property/home');
    } catch (e) {
      print('Error al cambiar de módulo: $e');
    }
  }

  // --- FUNCIÓN: VERIFICAR Y NAVEGAR A VISTA DE TRABAJADOR ---
  Future<void> _navigateToWorkerView() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    if (user == null) {
      Modular.to.navigate('/login');
      return;
    }

    try {
      // Verificar si el usuario ya tiene perfil de trabajador
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        // No existe el documento, ir a crear perfil
        Modular.to.pushNamed('/worker/edit-profile');
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final verificationStatus = userData['verificationStatus'] as String?;

      // NUEVO: Verificar si está verificado antes de permitir acceso
      if (verificationStatus != 'verified') {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Verificación Requerida'),
            content: const Text(
              'Para crear y acceder a tu perfil de trabajador, primero debes verificar tu identidad.\n\n'
              'Ve a la opción "Solicitar Verificado" en el menú para comenzar.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Modular.to.pushNamed('/worker/verification');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Styles.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Ir a Verificar'),
              ),
            ],
          ),
        );
        return;
      }

      final hasProfessions =
          (userData['professions'] as List<dynamic>?)?.isNotEmpty ?? false;

      // Si tiene profesiones seleccionadas, ir al módulo freelance
      if (hasProfessions) {
        Modular.to.pushNamed('/freelance/home');
      } else {
        // Si no tiene profesiones, ir a completar el perfil básico
        Modular.to.pushNamed('/worker/edit-profile');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al verificar perfil: $e')));
    }
  }

  // --- FUNCIÓN: MANEJAR SUSCRIPCIÓN PREMIUM ---
  Future<void> _handlePremiumSubscription() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    if (user == null) return;

    try {
      // 1. Verificar si ya es premium en la colección premium_users
      final premiumDoc = await FirebaseFirestore.instance
          .collection('premium_users')
          .doc(user.uid)
          .get();

      if (premiumDoc.exists && premiumDoc.data()?['status'] == 'active') {
        // Ya es premium -> Ir a estado
        Modular.to.pushNamed('/worker/subscription-status');
        return;
      }

      // 2. Verificar si tiene solicitud pendiente
      final requestsQuery = await FirebaseFirestore.instance
          .collection('subscription_requests')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (requestsQuery.docs.isNotEmpty) {
        // Si tiene solicitud (pendiente, aprobada o rechazada) -> Ir a estado
        Modular.to.pushNamed('/worker/subscription-status');
      } else {
        // No tiene nada -> Mostrar Modal Premium
        showDialog(
          context: context,
          builder: (context) => const PremiumSubscriptionModal(),
        );
      }
    } catch (e) {
      print('Error checking subscription: $e');
      // En caso de error, ir a la pantalla de estado que manejará la carga
      Modular.to.pushNamed('/worker/subscription-status');
    }
  }

  // --- Menú General de Trabajador ---
  Widget _buildWorkerMenu(Map<String, dynamic>? userData) {
    return AccountMenuSection(
      hasTitle: false,
      items: [
        AccountMenuItem(
          icon: Icons.person_outline,
          iconColor: const Color(0xFF6B7280),
          iconBgColor: const Color(0xFFF3F4F6),
          title: 'Editar perfil',
          subtitle: 'Actualiza tu información personal',
          onTap: () => Modular.to.pushNamed('/worker/edit-account'),
        ),
        AccountMenuSection.buildDivider(),
        AccountMenuItem(
          icon: Icons.verified_user_outlined,
          iconColor: const Color(0xFF4CAF50),
          iconBgColor: const Color(0xFFE8F5E9),
          title: 'Solicitar Verificado',
          subtitle: 'Verifica tu identidad y destaca',
          onTap: () => Modular.to.pushNamed('/worker/verification'),
        ),
        AccountMenuSection.buildDivider(),
        AccountMenuItem(
          icon: Icons.workspace_premium,
          iconColor: const Color(0xFFFFB800),
          iconBgColor: const Color(0xFFFFF7E6),
          title: 'Suscripción Premium',
          subtitle: 'Desbloquea funciones exclusivas',
          onTap: _handlePremiumSubscription,
        ),
        AccountMenuSection.buildDivider(),
        AccountMenuItem(
          icon: Icons.settings_outlined,
          iconColor: const Color(0xFF6B7280),
          iconBgColor: const Color(0xFFF3F4F6),
          title: 'Configuración',
          subtitle: 'Preferencias y opciones de cuenta',
          onTap: () => _showConfigurationOptions(userData),
        ),
        AccountMenuSection.buildDivider(),
        AccountMenuItem(
          icon: Icons.help_outline,
          iconColor: const Color(0xFF10B981),
          iconBgColor: const Color(0xFFD1FAE5),
          title: 'Ayuda y Soporte',
          subtitle: 'Contacta con nuestro equipo de soporte',
          onTap: _openSupportWhatsApp,
        ),
      ],
    );
  }

  bool _hasWorkerProfile(Map<String, dynamic>? userData) {
    if (userData == null) return false;

    // Consideramos que tiene perfil si tiene al menos una profesión
    return (userData['professions'] as List<dynamic>?)?.isNotEmpty ?? false;
  }

  void _showConfigurationOptions(Map<String, dynamic>? userData) {
    final hasWorkerProfile = _hasWorkerProfile(userData);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Configuración',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            if (hasWorkerProfile) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.person_remove, color: Colors.orange),
                title: const Text(
                  'Eliminar Cuenta de Trabajador',
                  style: TextStyle(color: Colors.orange),
                ),
                subtitle: const Text('Solo eliminar perfil de trabajador'),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteWorkerProfileDialog();
                },
              ),
            ],
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text(
                'Eliminar Cuenta',
                style: TextStyle(color: Colors.red),
              ),
              subtitle: const Text('Eliminar todo de forma permanente'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteAccountDialog();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showDeleteWorkerProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Cuenta de Trabajador'),
        content: const Text(
          'Esto eliminará tu perfil de trabajador, pero mantendrás tu cuenta de inmobiliaria.\n\n'
          '¿Estás seguro de continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteWorkerProfile();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar Perfil'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Cuenta'),
        content: const Text(
          'ADVERTENCIA: Esto eliminará permanentemente tu cuenta y todos tus datos:\n\n'
          '• Perfil de trabajador\n'
          '• Perfil de inmobiliaria\n'
          '• Chats y mensajes\n'
          '• Favoritos y guardados\n'
          '• Toda tu información\n\n'
          'Esta acción NO puede deshacerse.\n\n'
          '¿Estás ABSOLUTAMENTE seguro?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteCompleteAccount();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar Todo'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteWorkerProfile() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    if (user == null) return;

    try {
      // Mostrar loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final userId = user.uid;

      // 1. Limpiar campos de trabajador en el documento de usuario
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'professions': FieldValue.delete(),
        'profession': FieldValue.delete(),
        'price': FieldValue.delete(),
        'profile': FieldValue.delete(),
      });

      // 2. Eliminar vistas del perfil
      final viewsQuery = await FirebaseFirestore.instance
          .collection('profile_views')
          .where('workerId', isEqualTo: userId)
          .get();

      final viewsBatch = FirebaseFirestore.instance.batch();
      for (var doc in viewsQuery.docs) {
        viewsBatch.delete(doc.reference);
      }
      await viewsBatch.commit();

      // 3. Eliminar calificaciones y reseñas (feedback)
      final feedbackQuery = await FirebaseFirestore.instance
          .collection('feedback')
          .where('workerId', isEqualTo: userId)
          .get();

      final feedbackBatch = FirebaseFirestore.instance.batch();
      for (var doc in feedbackQuery.docs) {
        feedbackBatch.delete(doc.reference);
      }
      await feedbackBatch.commit();

      // Cerrar loading
      if (mounted) Navigator.pop(context);

      // Mostrar éxito y navegar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil de trabajador eliminado completamente'),
            backgroundColor: Colors.green,
          ),
        );
        // Navegar al módulo de inmobiliaria
        _changeModule();
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteCompleteAccount() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    if (user == null) return;

    try {
      // Mostrar loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final userId = user.uid;

      // 1. Eliminar chats donde el usuario participa
      final chatsQuery = await FirebaseFirestore.instance
          .collection('chats')
          .where('user_ids', arrayContains: userId)
          .get();

      for (var chatDoc in chatsQuery.docs) {
        await chatDoc.reference.delete();
      }

      // 2. Eliminar documentos de usuario en diferentes colecciones
      await Future.wait([
        FirebaseFirestore.instance.collection('users').doc(userId).delete(),
        FirebaseFirestore.instance
            .collection('saved_lists')
            .where('user_id', isEqualTo: userId)
            .get()
            .then((query) async {
              for (var doc in query.docs) {
                await doc.reference.delete();
              }
            }),
        FirebaseFirestore.instance
            .collection('notifications')
            .where('user_id', isEqualTo: userId)
            .get()
            .then((query) async {
              for (var doc in query.docs) {
                await doc.reference.delete();
              }
            }),
      ]);

      // 3. Eliminar usuario de Firebase Auth
      await user.delete();

      // 4. Cerrar sesión y navegar a login
      if (mounted) Navigator.pop(context);
      await authService.signOut();
      Modular.to.pushNamedAndRemoveUntil('/login', (p0) => false);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar cuenta: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showLogoutDialog(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Modular.to.pushNamedAndRemoveUntil('/login', (p0) => false);
              Modular.get<AuthService>().signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    if (user == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // StreamBuilder for premium status
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('premium_users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, premiumSnapshot) {
        // Check if user is premium
        final premiumData =
            premiumSnapshot.hasData &&
                premiumSnapshot.data!.exists &&
                premiumSnapshot.data!.data() != null
            ? premiumSnapshot.data!.data() as Map<String, dynamic>
            : null;
        final currentStatus = premiumData?['status'] as String?;
        final isPremium = currentStatus == 'active';

        // --- RESTORED LOGIC WITH ONE-SHOT PROTECTION ---
        if (isPremium && !_hasTriggeredPremiumAction) {
          _hasTriggeredPremiumAction = true; // LOCK IMMEDIATELY
          WidgetsBinding.instance.addPostFrameCallback((_) {
            PremiumNotificationService().handleNewPremiumUser(user.uid);
          });
        }
        // -----------------------------------------------

        return Scaffold(
          appBar: AppBar(
            title: const Text('Mi Cuenta - Empleador'),
            backgroundColor: isPremium
                ? Colors.transparent
                : Styles.primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: isPremium
                ? Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF6F00), // Vibrant Orange (solid)
                    ),
                  )
                : null,
          ),
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              // StreamBuilder for premium status
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('premium_users')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, premiumSnapshot) {
                  // Check if user is premium
                  final isPremium =
                      premiumSnapshot.hasData &&
                      premiumSnapshot.data!.exists &&
                      premiumSnapshot.data!.data() != null &&
                      (premiumSnapshot.data!.data()
                              as Map<String, dynamic>)['status'] ==
                          'active';

                  return StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.active) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Styles.primaryColor,
                          ),
                        );
                      }

                      final userData =
                          snapshot.data!.data() as Map<String, dynamic>?;

                      // Leer nombre con fallbacks múltiples
                      final displayName =
                          userData?['displayName'] ??
                          user.displayName ??
                          (userData?['phoneNumber'] as String?)?.substring(
                            0,
                            12,
                          ) ??
                          'Usuario';

                      final email =
                          userData?['email'] ?? user.email ?? 'Sin correo';

                      // Leer foto con múltiples fallbacks (photoURL y photoUrl)
                      final photoUrl =
                          userData?['photoURL'] ??
                          userData?['photoUrl'] ??
                          user.photoURL;

                      return SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header personalizado con estado de verificación
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: isPremium
                                    ? const LinearGradient(
                                        colors: [
                                          Color(0xFFFF6F00), // Vibrant Orange
                                          Color(0xFFFFC107), // Vibrant Yellow
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      )
                                    : LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Styles.primaryColor,
                                          Styles.primaryColor.withOpacity(0.8),
                                        ],
                                      ),
                              ),
                              child: SafeArea(
                                bottom: false,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 24,
                                  ),
                                  child: Column(
                                    children: [
                                      // Avatar con badge de verificación
                                      Stack(
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 3,
                                              ),
                                            ),
                                            child: CircleAvatar(
                                              radius: 50,
                                              backgroundColor: Colors.white,
                                              backgroundImage: photoUrl != null
                                                  ? NetworkImage(photoUrl)
                                                  : null,
                                              child: photoUrl == null
                                                  ? Icon(
                                                      Icons.person,
                                                      size: 50,
                                                      color: Colors.grey[400],
                                                    )
                                                  : null,
                                            ),
                                          ),
                                          if (userData?['verificationStatus'] ==
                                              'verified')
                                            Positioned(
                                              bottom: 0,
                                              right: 0,
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  6,
                                                ),
                                                decoration: const BoxDecoration(
                                                  color: Colors.white,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.verified,
                                                  color: Color(0xFF4CAF50),
                                                  size: 24,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),

                                      // Nombre
                                      Text(
                                        displayName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 4),

                                      // Email
                                      Text(
                                        email,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 14,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 16),

                                      // Chips de Plan y Verificación
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isPremium
                                                  ? const Color(
                                                      0xFFFFD700,
                                                    ).withOpacity(0.3)
                                                  : Colors.white.withOpacity(
                                                      0.2,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: isPremium
                                                  ? Border.all(
                                                      color: const Color(
                                                        0xFFFFD700,
                                                      ),
                                                      width: 1.5,
                                                    )
                                                  : null,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (isPremium)
                                                  const Padding(
                                                    padding: EdgeInsets.only(
                                                      right: 4.0,
                                                    ),
                                                    child: Icon(
                                                      Icons.workspace_premium,
                                                      color: Color(0xFFFFD700),
                                                      size: 16,
                                                    ),
                                                  ),
                                                Text(
                                                  isPremium
                                                      ? 'Plan Premium'
                                                      : 'Plan Gratuito',
                                                  style: TextStyle(
                                                    color: isPremium
                                                        ? const Color(
                                                            0xFFFFD700,
                                                          )
                                                        : Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: isPremium
                                                        ? FontWeight.bold
                                                        : FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Estado de Verificación
                                          const SizedBox(width: 8),
                                          if (userData?['verificationStatus'] ==
                                              'verified')
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF4CAF50),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: const [
                                                  Icon(
                                                    Icons.check_circle,
                                                    color: Colors.white,
                                                    size: 14,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Verificado',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          else if (userData?['verificationStatus'] ==
                                              'pending')
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.orange,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: const [
                                                  Icon(
                                                    Icons.schedule,
                                                    color: Colors.white,
                                                    size: 14,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'En revisión',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          else if (userData?['verificationStatus'] ==
                                              'rejected')
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.red.shade400,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: const [
                                                  Icon(
                                                    Icons.error_outline,
                                                    color: Colors.white,
                                                    size: 14,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Rechazado',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          else
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(
                                                  0.2,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: const [
                                                  Icon(
                                                    Icons.info_outline,
                                                    color: Colors.white,
                                                    size: 14,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Sin verificar',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Sección Principal - Cambiar Módulo + Vista de Trabajador
                            AccountMenuSection(
                              title: 'Perfil de Trabajador',
                              items: [
                                AccountMenuItem(
                                  icon: Icons.swap_horiz,
                                  iconColor: Styles.infoColor,
                                  iconBgColor: Styles.infoColor.withOpacity(
                                    0.1,
                                  ),
                                  title: 'Cambiar de Módulo',
                                  subtitle: 'Ve a la sección de Inmobiliaria',
                                  onTap: _changeModule,
                                ),
                                AccountMenuSection.buildDivider(),
                                AccountMenuItem(
                                  icon: Icons.work_outline,
                                  iconColor: Colors.purple.shade600,
                                  iconBgColor: Colors.purple.shade600
                                      .withOpacity(0.1),
                                  title: 'Mi Perfil de Trabajador',
                                  subtitle:
                                      'Administra tu perfil y servicios que ofreces',
                                  onTap: _navigateToWorkerView,
                                ),
                              ],
                            ),

                            // Menú General
                            _buildWorkerMenu(userData),

                            // Botón Cerrar sesión
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: Styles.spacingMedium,
                              ),
                              child: SizedBox(
                                width: double.infinity,
                                child: TextButton.icon(
                                  onPressed: () =>
                                      _showLogoutDialog(context, authService),
                                  icon: const Icon(
                                    Icons.logout,
                                    color: Color(0xFFEF4444),
                                    size: 20,
                                  ),
                                  label: const Text(
                                    'Cerrar sesión',
                                    style: TextStyle(
                                      color: Color(0xFFEF4444),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                      vertical: Styles.spacingMedium,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: Styles.spacingLarge),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
