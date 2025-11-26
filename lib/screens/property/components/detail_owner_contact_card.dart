import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../theme/theme.dart';

// Interfaz necesaria para delegar la lógica de contacto a la clase State (la que tiene acceso al context)
abstract class DetailOwnerContactCardCallbacks {
  Future<void> contactOwner(String type);
  void startInternalChat();
}

class DetailOwnerContactCard extends StatelessWidget {
  final Map<String, dynamic>? ownerData;
  final String? propertyName;
  final DetailOwnerContactCardCallbacks callbacks;

  const DetailOwnerContactCard({
    super.key,
    required this.ownerData,
    required this.propertyName,
    required this.callbacks,
  });

  Widget _buildOwnerCard() {
    final name = ownerData?['displayName'] ?? 'Usuario Mobiliaria';
    final photoUrl = ownerData?['photoURL'];

    return GestureDetector(
      onTap: () {
        // TODO: Navegación al perfil del propietario (opcional)
        // Modular.to.pushNamed('/property/public-profile', arguments: ownerData);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Styles.primaryColor.withOpacity(0.1),
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null
                  ? Text(
                      name[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 20,
                        color: Styles.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Propietario / Agente',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildContactButtons() {
    return Padding(
      padding: EdgeInsets.only(top: Styles.spacingMedium),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => callbacks.contactOwner('call'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                foregroundColor: Colors.black87,
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.phone, size: 20),
                  SizedBox(height: 2),
                  Text('Llamar', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: callbacks.startInternalChat,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                foregroundColor: Styles.primaryColor,
                side: const BorderSide(color: Styles.primaryColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: Styles.primaryColor.withOpacity(0.05),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 20),
                  SizedBox(height: 2),
                  Text(
                    'Chat',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: () => callbacks.contactOwner('whatsapp'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FaIcon(FontAwesomeIcons.whatsapp, size: 20),
                  SizedBox(height: 2),
                  Text(
                    'WhatsApp',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(Styles.spacingLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contacto',
            style: TextStyles.subtitle.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildOwnerCard(),
          _buildContactButtons(),
        ],
      ),
    );
  }
}
