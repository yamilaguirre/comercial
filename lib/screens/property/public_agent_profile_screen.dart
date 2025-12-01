import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/mobiliaria_provider.dart';
import '../../models/property.dart';
import '../../services/agent_stats_service.dart';

import 'components/profile_header_section.dart';
import 'components/profile_components.dart';

// Modelo de datos simplificado para un perfil público (simulación)
class PublicProfileData {
  final String name;
  final String role;
  final String? photoUrl;
  final String phone;
  final String email;

  PublicProfileData({
    required this.name,
    required this.role,
    this.photoUrl,
    required this.phone,
    required this.email,
  });
}

// Pantalla que ve un cliente/usuario cuando revisa el perfil de un agente.
class PublicAgentProfileScreen extends StatefulWidget {
  PublicAgentProfileScreen({super.key});

  @override
  State<PublicAgentProfileScreen> createState() =>
      _PublicAgentProfileScreenState();
}

class _PublicAgentProfileScreenState extends State<PublicAgentProfileScreen> {
  Map<String, dynamic>? userData;
  List<Property> userProperties = [];
  Map<String, dynamic> stats = {};
  bool isLoading = true;
  final AgentStatsService _statsService = AgentStatsService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final authService = Modular.get<AuthService>();
      final user = authService.currentUser;

      if (user != null) {
        // Cargar datos del usuario
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          userData = userDoc.data();
        }

        // Cargar propiedades del usuario
        final mobiliariaProvider = Modular.get<MobiliariaProvider>();
        userProperties = await mobiliariaProvider.fetchUserProperties();

        // Cargar estadísticas
        stats = await _statsService.getAgentStats(user.uid);
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _launchUrl(Uri uri, BuildContext context) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'No se pudo lanzar $uri';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir la aplicación: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Styles.primaryColor),
        ),
      );
    }

    final displayName = userData?['displayName'] ?? 'Usuario';
    final email = userData?['email'] ?? 'Sin correo';
    final phone = userData?['phoneNumber'] ?? 'Sin teléfono';
    final photoUrl = userData?['photoURL'];
    final userRole = userData?['role'] ?? 'cliente';

    final Map<String, String> publicStats = {
      'Publicaciones': (stats['totalProperties'] ?? 0).toString(),
      'Vistas': _formatNumber(stats['totalViews'] ?? 0),
      'Consultas': (stats['totalInquiries'] ?? 0).toString(),
    };

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              // 1. Cabecera (Parte Constante y No-Editable)
              ProfileHeaderSection(
            name: displayName,
            role: userRole == 'inmobiliaria'
                ? 'Agente Inmobiliario'
                : 'Usuario',
            photoUrl: photoUrl,
            isVerified: true,
            stats: publicStats,
            showPlanBadge: false,
            onSettingsTap: () {},
          ),

          // 2. Contenido Deslizable (Información Pública)
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(Styles.spacingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: Styles.spacingMedium),

                  // --- Contacto Público ---
                  Text(
                    'Información de contacto',
                    style: TextStyles.subtitle.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.only(top: Styles.spacingMedium),
                    padding: EdgeInsets.all(Styles.spacingMedium),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ContactInfoItem(
                          icon: Icons.person_outline,
                          label: 'Nombre del Agente',
                          value: displayName,
                          onTap: () {},
                          isEditable: false,
                        ),
                        const Divider(),
                        ContactInfoItem(
                          icon: Icons.phone_outlined,
                          label: 'Llamar',
                          value: phone,
                          onTap: () {
                            final uri = Uri.parse('tel:$phone');
                            _launchUrl(uri, context);
                          },
                          isEditable: true,
                        ),
                        const Divider(),
                        ContactInfoItem(
                          icon: Icons.email_outlined,
                          label: 'Enviar Correo',
                          value: email,
                          onTap: () {
                            final uri = Uri.parse('mailto:$email');
                            _launchUrl(uri, context);
                          },
                          isEditable: true,
                        ),
                        const Divider(),
                        ContactInfoItem(
                          icon: FontAwesomeIcons.whatsapp,
                          label: 'WhatsApp',
                          value: 'Contactar por WhatsApp',
                          onTap: () {
                            final message = Uri.encodeComponent(
                              'Hola, vi tu perfil en la app Comercial y me gustaría consultarte.',
                            );
                            final uri = Uri.parse(
                              "https://wa.me/$phone?text=$message",
                            );
                            _launchUrl(uri, context);
                          },
                          isEditable: true,
                          iconColor: const Color(0xFF25D366),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: Styles.spacingLarge),

                  // --- Propiedades/Servicios Activos ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Mis Publicaciones (${userProperties.length})',
                        style: TextStyles.subtitle.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => Modular.to.pushNamed('/property/new'),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Nueva'),
                        style: TextButton.styleFrom(
                          foregroundColor: Styles.primaryColor,
                        ),
                      ),
                    ],
                  ),

                  if (userProperties.isEmpty)
                    Container(
                      padding: EdgeInsets.all(Styles.spacingLarge),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.home_outlined,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Aún no tienes propiedades publicadas',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...userProperties
                        .take(6)
                        .map((property) => _buildPropertyCard(property)),

                  SizedBox(height: Styles.spacingLarge * 2),
                ],
              ),
            ),
          ),
            ],
          ),
          // Botón de retroceso
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Modular.to.navigate('/property/account'),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyCard(Property property) {
    return Card(
      margin: EdgeInsets.only(bottom: Styles.spacingMedium),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Modular.to.pushNamed('/property/detail/${property.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(Styles.spacingMedium),
          child: Row(
            children: [
              // Imagen
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey[200],
                  child: property.imageUrl.isNotEmpty
                      ? Image.network(
                          property.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.home,
                                size: 40,
                                color: Colors.grey,
                              ),
                        )
                      : const Icon(Icons.home, size: 40, color: Colors.grey),
                ),
              ),
              SizedBox(width: Styles.spacingMedium),
              // Información
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      property.location,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      property.price,
                      style: const TextStyle(
                        color: Styles.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              // Botón editar
              IconButton(
                onPressed: () =>
                    Modular.to.pushNamed('/property/new', arguments: property),
                icon: const Icon(Icons.edit, color: Styles.primaryColor),
                tooltip: 'Editar',
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}
