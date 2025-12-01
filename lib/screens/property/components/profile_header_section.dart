import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../theme/theme.dart';
import 'profile_components.dart';

class ProfileHeaderSection extends StatelessWidget {
  final String name;
  final String role;
  final String? photoUrl;
  final bool isVerified;
  // stats debe contener { 'Activas': '12', 'Consultas': '8', 'Visitas': '2.8K' }
  final Map<String, String> stats;
  final VoidCallback onSettingsTap;
  final bool showPlanBadge;
  final String? memberSince;

  const ProfileHeaderSection({
    super.key,
    required this.name,
    required this.role,
    this.photoUrl,
    this.isVerified = true,
    required this.stats,
    required this.onSettingsTap,
    this.showPlanBadge = true,
    this.memberSince,
  });

  @override
  Widget build(BuildContext context) {
    // Definimos las claves para evitar errores si faltan datos
    final statActivas = stats['Activas'] ?? '0';
    final statConsultas = stats['Consultas'] ?? '0';
    final statVisitas = stats['Visitas'] ?? '0';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        Styles.spacingLarge,
        Styles.spacingLarge,
        Styles.spacingSmall,
        Styles.spacingLarge,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Styles.primaryColor, // Azul fuerte
            Styles.primaryColor.withOpacity(0.9),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Avatar y Nombre centrados
            Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.white,
                      backgroundImage: photoUrl != null
                          ? NetworkImage(photoUrl!)
                          : null,
                      child: photoUrl == null
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'U',
                              style: TextStyles.title.copyWith(
                                fontSize: 30,
                                color: Styles.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    if (showPlanBadge)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Text(
                            'G',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: TextStyles.title.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      role,
                      style: TextStyles.body.copyWith(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isVerified)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade600,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: Colors.white,
                              size: 12,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Verificado',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (memberSince != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Miembro desde $memberSince',
                    style: TextStyles.caption.copyWith(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),

            SizedBox(height: Styles.spacingLarge),

            // Tarjetas de Estadísticas
            Row(
              children: [
                ProfileStatCard(label: 'Activas', value: statActivas),
                SizedBox(width: Styles.spacingSmall),
                ProfileStatCard(label: 'Consultas', value: statConsultas),
                SizedBox(width: Styles.spacingSmall),
                ProfileStatCard(label: 'Visitas', value: statVisitas),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
