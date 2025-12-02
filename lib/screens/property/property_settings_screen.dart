import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import '../../theme/theme.dart';

class PropertySettingsScreen extends StatefulWidget {
  const PropertySettingsScreen({super.key});

  @override
  State<PropertySettingsScreen> createState() => _PropertySettingsScreenState();
}

class _PropertySettingsScreenState extends State<PropertySettingsScreen> {
  bool _notificationsEnabled = true;
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _darkMode = false;
  String _language = 'Español';

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          Modular.to.navigate('/property/account');
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Styles.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Modular.to.navigate('/property/account'),
          ),
          title: const Text('Configuración'),
        ),
        body: ListView(
          padding: EdgeInsets.all(Styles.spacingMedium),
          children: [
            _buildSection(
              'Notificaciones',
              [
                _buildSwitchTile(
                  'Notificaciones',
                  'Recibir notificaciones de la app',
                  _notificationsEnabled,
                  (value) => setState(() => _notificationsEnabled = value),
                  Icons.notifications_outlined,
                ),
                _buildSwitchTile(
                  'Notificaciones por correo',
                  'Recibir actualizaciones por email',
                  _emailNotifications,
                  (value) => setState(() => _emailNotifications = value),
                  Icons.email_outlined,
                ),
                _buildSwitchTile(
                  'Notificaciones push',
                  'Alertas en tiempo real',
                  _pushNotifications,
                  (value) => setState(() => _pushNotifications = value),
                  Icons.phone_android,
                ),
              ],
            ),
            SizedBox(height: Styles.spacingLarge),
            _buildSection(
              'Apariencia',
              [
                _buildSwitchTile(
                  'Modo oscuro',
                  'Cambiar tema de la aplicación',
                  _darkMode,
                  (value) => setState(() => _darkMode = value),
                  Icons.dark_mode_outlined,
                ),
                _buildTile(
                  'Idioma',
                  _language,
                  Icons.language,
                  () => _showLanguageDialog(),
                ),
              ],
            ),
            SizedBox(height: Styles.spacingLarge),
            _buildSection(
              'Privacidad',
              [
                _buildTile(
                  'Política de privacidad',
                  'Ver términos y condiciones',
                  Icons.privacy_tip_outlined,
                  () => _showSnackBar('Próximamente'),
                ),
                _buildTile(
                  'Términos de uso',
                  'Condiciones del servicio',
                  Icons.description_outlined,
                  () => _showSnackBar('Próximamente'),
                ),
              ],
            ),
            SizedBox(height: Styles.spacingLarge),
            _buildSection(
              'Cuenta',
              [
                _buildTile(
                  'Cambiar contraseña',
                  'Actualizar tu contraseña',
                  Icons.lock_outline,
                  () => _showSnackBar('Próximamente'),
                ),
                _buildTile(
                  'Eliminar cuenta',
                  'Borrar permanentemente tu cuenta',
                  Icons.delete_outline,
                  () => _showDeleteAccountDialog(),
                  isDestructive: true,
                ),
              ],
            ),
            SizedBox(height: Styles.spacingLarge),
            Center(
              child: Text(
                'Versión 1.0.0',
                style: TextStyles.caption.copyWith(
                  color: Styles.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: Styles.spacingSmall, bottom: Styles.spacingSmall),
          child: Text(
            title,
            style: TextStyles.subtitle.copyWith(
              fontWeight: FontWeight.bold,
              color: Styles.textPrimary,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
    IconData icon,
  ) {
    return ListTile(
      leading: Icon(icon, color: Styles.primaryColor),
      title: Text(title, style: TextStyles.body.copyWith(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyles.caption),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Styles.primaryColor,
      ),
    );
  }

  Widget _buildTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : Styles.primaryColor,
      ),
      title: Text(
        title,
        style: TextStyles.body.copyWith(
          fontWeight: FontWeight.w500,
          color: isDestructive ? Colors.red : Styles.textPrimary,
        ),
      ),
      subtitle: Text(subtitle, style: TextStyles.caption),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar idioma'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Español'),
              value: 'Español',
              groupValue: _language,
              onChanged: (value) {
                setState(() => _language = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('English'),
              value: 'English',
              groupValue: _language,
              onChanged: (value) {
                setState(() => _language = value!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar tu cuenta? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSnackBar('Función en desarrollo');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
