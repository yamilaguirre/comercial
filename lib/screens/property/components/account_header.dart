import 'package:flutter/material.dart';
import '../../../theme/theme.dart';

class AccountHeader extends StatelessWidget {
  final String displayName;
  final String email;
  final String? photoUrl;
  final String userRole;
  final String? verificationStatus;
  final bool isPremium;

  const AccountHeader({
    super.key,
    required this.displayName,
    required this.email,
    this.photoUrl,
    required this.userRole,
    this.verificationStatus,
    this.isPremium = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: Styles.spacingLarge,
        bottom: Styles.spacingLarge,
      ),
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
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Styles.primaryColor,
                  Styles.primaryColor.withOpacity(0.8),
                ],
              ),
      ),
      child: Column(
        children: [
          // Avatar con badge de verificación
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: photoUrl != null
                      ? NetworkImage(photoUrl!)
                      : null,
                  child: photoUrl == null
                      ? Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            fontSize: 40,
                            color: Styles.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
              if (verificationStatus == 'verified')
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
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

          SizedBox(height: Styles.spacingMedium),

          // Nombre
          Text(
            displayName,
            style: TextStyles.title.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          SizedBox(height: Styles.spacingXSmall),

          // Email y Rol actual
          Column(
            children: [
              Text(
                email,
                style: TextStyles.body.copyWith(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  userRole == 'cliente'
                      ? 'ROL NO DEFINIDO'
                      : userRole.toString().toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: Styles.spacingMedium),

          // Chips de Plan y Verificación
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Plan Premium o Gratuito
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isPremium
                      ? const Color(0xFFFFD700).withOpacity(0.3)
                      : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: isPremium
                      ? Border.all(color: const Color(0xFFFFD700), width: 1.5)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isPremium)
                      const Icon(
                        Icons.workspace_premium,
                        color: Color(0xFFFFD700),
                        size: 16,
                      ),
                    if (isPremium) const SizedBox(width: 4),
                    Text(
                      isPremium ? 'Plan Premium' : 'Plan Gratuito',
                      style: TextStyle(
                        color: isPremium
                            ? const Color(0xFFFFD700)
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
              if (verificationStatus == 'verified')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.check_circle, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Verificado',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              else if (verificationStatus == 'pending')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.schedule, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'En revisión',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              else if (verificationStatus == 'rejected')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade400,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.error_outline, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Rechazado',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.info_outline, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Sin verificar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
