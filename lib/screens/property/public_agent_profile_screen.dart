import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/theme.dart';

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
class PublicAgentProfileScreen extends StatelessWidget {
  // Simulación: en una app real, esto vendría de Modular.args.data o se buscaría por ID.
  final PublicProfileData mockAgentData = PublicProfileData(
    name: 'Juan Pérez',
    role: 'Agente Inmobiliario',
    photoUrl: 'https://placehold.co/100x100/A3B8E8/ffffff?text=JP',
    phone: '59171234567', // Número limpio para lanzar
    email: 'juan.perez@email.com',
  );

  PublicAgentProfileScreen({super.key});

  // Simulación de estadísticas visibles al público
  final Map<String, String> _publicStats = {
    'Activas': '12',
    'Consultas': '8',
    'Visitas': '2.8K',
  };

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
    // Definimos el Stat de Contacto para el pie de la cabecera
    final Map<String, String> publicStats = {
      'Publicaciones': _publicStats['Activas'] ?? '0',
      'Consultas': _publicStats['Consultas'] ?? '0',
      'Contactos':
          _publicStats['Visitas'] ??
          '0', // Usamos Visitas como proxy de interacciones
    };

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 1. Cabecera (Parte Constante y No-Editable)
          ProfileHeaderSection(
            name: mockAgentData.name,
            role: mockAgentData.role,
            photoUrl: mockAgentData.photoUrl,
            isVerified: true,
            stats: publicStats,
            showPlanBadge: false, // El cliente no ve el plan interno
            onSettingsTap: () =>
                Modular.to.pop(), // Reemplazamos ajustes por botón de volver
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
                          value: mockAgentData.name,
                          onTap: () {},
                          isEditable: false,
                        ),
                        const Divider(),
                        ContactInfoItem(
                          icon: Icons.phone_outlined,
                          label: 'Llamar',
                          value: mockAgentData.phone,
                          onTap: () {
                            final uri = Uri.parse('tel:${mockAgentData.phone}');
                            _launchUrl(uri, context);
                          },
                          isEditable: true,
                        ),
                        const Divider(),
                        ContactInfoItem(
                          icon: Icons.email_outlined,
                          label: 'Enviar Correo',
                          value: mockAgentData.email,
                          onTap: () {
                            final uri = Uri.parse(
                              'mailto:${mockAgentData.email}',
                            );
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
                              'Hola, vi tu perfil en MobiliariaApp y me gustaría consultarte.',
                            );
                            final uri = Uri.parse(
                              "https://wa.me/${mockAgentData.phone}?text=$message",
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
                  Text(
                    'Publicaciones Activas',
                    style: TextStyles.subtitle.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Aquí se cargarían las tarjetas de propiedades del agente
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: Styles.spacingMedium,
                    ),
                    child: Center(
                      child: Text(
                        'Mostrando las últimas 3 publicaciones de ${mockAgentData.name}',
                        style: TextStyles.caption.copyWith(color: Colors.grey),
                      ),
                    ),
                  ),

                  // Simulación de tarjeta de propiedad
                  Container(
                    height: 120,
                    margin: EdgeInsets.only(bottom: Styles.spacingMedium),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'Tarjeta de Propiedad 1',
                        style: TextStyle(color: Styles.textSecondary),
                      ),
                    ),
                  ),
                  Container(
                    height: 120,
                    margin: EdgeInsets.only(bottom: Styles.spacingMedium),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'Tarjeta de Propiedad 2',
                        style: TextStyle(color: Styles.textSecondary),
                      ),
                    ),
                  ),

                  SizedBox(height: Styles.spacingLarge * 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
