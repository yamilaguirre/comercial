import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../theme/theme.dart';

class InmobiliariaProfileScreen extends StatefulWidget {
  const InmobiliariaProfileScreen({super.key});

  @override
  State<InmobiliariaProfileScreen> createState() =>
      _InmobiliariaProfileScreenState();
}

class _InmobiliariaProfileScreenState extends State<InmobiliariaProfileScreen> {
  final AuthService _authService = Modular.get<AuthService>();

  Future<void> _handleLogout() async {
    await _authService.signOut();
    if (mounted) {
      Modular.to.navigate('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Perfil Empresarial'),
        backgroundColor: Styles.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Styles.primaryColor),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final companyName = data?['companyName'] ?? 'Empresa';
          final companyLogo = data?['companyLogo'];
          final isAgent = data?['isAgent'] ?? false;
          final documentLabel = isAgent ? 'CI' : 'NIT';
          final documentNumber = data?['documentNumber'] ?? 'N/A';
          final address = data?['address'] ?? 'N/A';
          final phoneNumbers = (data?['phoneNumbers'] as List<dynamic>?) ?? [];
          final email = data?['email'] ?? 'N/A';
          final representative = data?['representativeName'] ?? 'N/A';

          return SingleChildScrollView(
            padding: EdgeInsets.all(Styles.spacingMedium),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(Styles.spacingLarge),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      if (companyLogo != null)
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: NetworkImage(companyLogo),
                        )
                      else
                        const CircleAvatar(
                          radius: 50,
                          child: Icon(Icons.business, size: 50),
                        ),
                      SizedBox(height: Styles.spacingMedium),
                      Text(
                        companyName,
                        style: TextStyles.title.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isAgent ? 'Agente Inmobiliario' : 'Inmobiliaria',
                        style: TextStyles.body.copyWith(
                          color: Styles.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: Styles.spacingMedium),
                _buildInfoSection('Información de la Empresa', [
                  _buildInfoTile(Icons.badge, documentLabel, documentNumber),
                  _buildInfoTile(Icons.location_on, 'Dirección', address),
                  ...phoneNumbers.asMap().entries.map((entry) {
                    final index = entry.key;
                    final phone = entry.value.toString();
                    final label = phoneNumbers.length > 1
                        ? 'Teléfono ${index + 1}'
                        : 'Teléfono';
                    return _buildInfoTile(Icons.phone, label, phone);
                  }),
                  _buildInfoTile(Icons.email, 'Correo', email),
                  if (!isAgent)
                    _buildInfoTile(
                      Icons.person,
                      'Representante',
                      representative,
                    ),
                ]),
                SizedBox(height: Styles.spacingMedium),
                _buildInfoSection('Configuración', [
                  _buildActionTile(
                    Icons.edit,
                    'Editar Perfil',
                    () => Modular.to.pushNamed('/inmobiliaria/edit-profile'),
                  ),
                ]),
                SizedBox(height: Styles.spacingMedium),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _handleLogout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Cerrar Sesión'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: Styles.spacingMedium,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(Styles.spacingMedium),
            child: Text(
              title,
              style: TextStyles.subtitle.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: Styles.primaryColor),
      title: Text(label, style: TextStyles.caption),
      subtitle: Text(value, style: TextStyles.body),
    );
  }

  Widget _buildActionTile(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Styles.primaryColor),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
